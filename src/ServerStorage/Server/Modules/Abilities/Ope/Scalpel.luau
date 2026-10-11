--!strict
--[[
	Ope fruit - Scalpel: reach into a player's chest and take their heart, then squeeze it.

	Without a heart in hand - the steal:
	  Needs the caster inside their open Room.
	  Cost: clamp(80 * sword affinity * (sword level / cap), 10, 300) stamina, hit or miss.
	  For half a second the hand is "out": the first player found in a small box in
	  front of the caster, or swapped with Shambles meanwhile, loses their heart
	  (stunned 2 s). A player's heart can be stolen once per life.

	With a heart in hand - the squeeze (the same key; the legacy gave a Heart tool):
	  Works from anywhere, three times per heart, cooldown 5 * (3 - sword affinity) s.
	  Victim at or below 25% * affinity of max health: killed.
	  Otherwise: 10% * affinity of its max health as damage.
	  Either way the victim is stunned 0.5 + (affinity - 1) s (affinity term clamped 0-1).
	  The heart is lost with the third squeeze, or when either side dies (a dead
	  victim is noticed on the next press: nothing watches it).

	Statuses: "OpeHeartStolen" on the victim and "OpeHeart" (victim name) on the caster,
	both replicated for the HUD; Effects.Status.OpeHeart puts the heart in the caster's hand.

	Legacy problems fixed here:
	- The steal was a Touched connection on the right arm that lived as long as an
	  animation played at 12x speed, so it depended on the animation asset loading.
	- The connection and the sword affinity were script globals shared with Shambles.
	- The squeeze subtracted the Health value directly: no kill credit, no damage
	  number, and it ignored spawn protection. It goes through the combat pipeline now
	  (so resistances apply to it: see the report).
	- The heart is kept through a stun or seal of the caster, as the tool was; it is
	  dropped when the caster dies or loses the fruit.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local OpeRoom = require(script.Parent.OpeRoom)

type CharacterEntity = CharacterEntity.CharacterEntity

local HEART_STATUS = "OpeHeart"
-- Non-replicated: the heart in hand. Kept on the entity, not on the ability object,
-- because the object is rebuilt whenever either fruit slot changes.
local HEART_STATE_STATUS = "OpeHeartState"
local STOLEN_STATUS = "OpeHeartStolen"
local SWAP_STATUS = "OpeShamblesSwap"

local HITBOX_SIZE = Vector3.new(5, 5, 5)
local HITBOX_DISTANCE = 3
local REACH_CHECKS = 3
local REACH_INTERVAL = 0.15
local STEAL_STUN = 2
local HEART_USES = 3
local KILL_FRACTION = 0.25
local SQUEEZE_FRACTION = 0.1
-- Large enough to go through any shield or resistance.
local KILL_DAMAGE_SCALE = 100

type Heart = {
	Target: CharacterEntity,
	Uses: number,
	Affinity: number,
	LastSqueeze: number,
}

local function canLoseHeart(target: CharacterEntity): boolean
	return target.Player ~= nil and not target.Dead and not target:HasStatus(STOLEN_STATUS)
end

local Scalpel = Ability.extend()

function Scalpel:CanBegin(): boolean
	return not self.Entity:HasStatus(OpeRoom.ProjectingStatus)
end

function Scalpel:DropHeart()
	self.Entity:ClearStatus(HEART_STATE_STATUS)
	self.Entity:ClearStatus(HEART_STATUS)
end

function Scalpel:StopReaching()
	self.Reach = (self.Reach or 0) + 1
	if self.UsedConnection then
		self.UsedConnection:Disconnect()
		self.UsedConnection = nil
	end
end

function Scalpel:Steal(target: CharacterEntity)
	self:StopReaching()

	self.Services.Status:ApplyStun(target, STEAL_STUN, "OpeHeartSteal")
	target:SetStatus(STOLEN_STATUS, true, nil, true)

	local heart: Heart = {
		Target = target,
		Uses = 0,
		Affinity = self:GetAffinity("Sword"),
		LastSqueeze = 0,
	}
	self.Entity:SetStatus(HEART_STATE_STATUS, heart)
	self.Entity:SetStatus(HEART_STATUS, target.Model.Name, nil, true)
end

function Scalpel:Squeeze(heart: Heart)
	local target = heart.Target
	if target.Dead or target.Model.Parent == nil then
		self:DropHeart()
		return
	end

	local affinity = heart.Affinity
	local now = os.clock()
	if now - heart.LastSqueeze < 5 * (3 - affinity) then
		return
	end
	heart.LastSqueeze = now
	self:StartCooldown(5 * (3 - affinity))
	heart.Uses += 1

	if target.Health <= math.floor(target.MaxHealth * KILL_FRACTION * affinity) then
		self:Damage(target, target.MaxHealth * KILL_DAMAGE_SCALE, "Special", "OpeHeart", false)
	else
		self:Damage(target, math.floor(target.MaxHealth * SQUEEZE_FRACTION * affinity), "Special", "OpeHeart", false)
	end

	if target.Dead then
		self:DropHeart()
		return
	end
	self.Services.Status:ApplyStun(target, 0.5 + math.clamp(affinity - 1, 0, 1), "OpeHeartSqueeze")
	if heart.Uses >= HEART_USES then
		self:DropHeart()
	end
end

function Scalpel:OnBegin()
	local entity = self.Entity
	local heart = entity:GetStatus(HEART_STATE_STATUS) :: Heart?
	if heart then
		self:Squeeze(heart)
		return
	end

	if not OpeRoom.Contains(entity, entity.Root.Position) then
		return
	end
	local cost = math.clamp(80 * self:GetAffinity("Sword") * self:GetLevelScale("Sword"), 10, 300)
	if not OpeRoom.Spend(entity, cost) then
		return
	end

	self:PlayEffect("OpeScalpel", entity.Root.Position)

	self:StopReaching()
	local reach = self.Reach

	-- Shambles used while the hand is out: whoever was swapped loses their heart.
	self.UsedConnection = self.Services.Ability.Used:Connect(
		function(user: CharacterEntity, _fruitName: string, abilityName: string)
			if user ~= entity or abilityName ~= "Shambles" or self.Reach ~= reach then
				return
			end
			local swapped = entity:GetStatus(SWAP_STATUS) :: CharacterEntity?
			if swapped and canLoseHeart(swapped) then
				entity:ClearStatus(SWAP_STATUS)
				self:Steal(swapped)
			end
		end
	)

	local checks = 0
	local function check()
		if self.Reach ~= reach then
			return
		end

		local closest: CharacterEntity? = nil
		local closestDistance = math.huge
		for _, candidate in Hitbox.InFront(entity, HITBOX_SIZE, HITBOX_DISTANCE) do
			local distance = (candidate.Root.Position - entity.Root.Position).Magnitude
			if distance < closestDistance and canLoseHeart(candidate) then
				closest, closestDistance = candidate, distance
			end
		end
		if closest then
			self:Steal(closest)
			return
		end

		checks += 1
		if checks > REACH_CHECKS then
			self:StopReaching()
			return
		end
		task.delay(REACH_INTERVAL, check)
	end
	check()
end

function Scalpel:OnInterrupt()
	self:StopReaching()

	-- A stun or seal does not take the heart away; death or losing the fruit does.
	local entity = self.Entity
	local player = self.Player
	local keep = not entity.Dead
		and entity.Model.Parent ~= nil
		and player.Parent ~= nil
		and self.Services.Fruit:HasFruit(player, self.Context.FruitName)
	if not keep then
		self:DropHeart()
	end
end

return Scalpel
