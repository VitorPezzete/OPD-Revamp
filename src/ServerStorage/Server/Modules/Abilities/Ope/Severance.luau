--!strict
--[[
	Ope fruit - Severance: cuts the aimed character apart inside the Room. No damage:
	the victim is held in place (stunned) while its limbs float away, then reassembles.

	Needs:    caster and target inside the caster's open Room
	Cost:     clamp(60 * sword affinity * (sword level / cap), 10, 200) stamina
	Duration: clamp(3 * sword affinity * (sword level / cap), 1, 8) seconds
	Cooldown: 13 s per victim for this caster (nothing happens, nothing is spent), and
	          13 s on the victim shared by every Ope user: a cut refused by that one
	          still costs the stamina and starts the caster's own 13 s, as in the legacy
	          game (it only shows with two Ope users on the same victim).

	The stun is a StatusService stun named "OpeSevered"; the replicated "OpeSevered"
	status on the victim is drawn by Effects.Status.OpeSevered.

	Legacy problems fixed here:
	- The client sent the part under its mouse as the target.
	- The victim's shoulder and hip joints were destroyed and rebuilt on the server
	  (limbs fell through the map when it died meanwhile); limbs are now only moved
	  visually, on each client.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local OpeRoom = require(script.Parent.OpeRoom)

local STATUS = "OpeSevered"
local COOLDOWN_STATUS = "OpeSeveredCooldown"

local AIM_RADIUS = 5
local VICTIM_COOLDOWN = 13

local Severance = Ability.extend()

function Severance:CanBegin(): boolean
	return not self.Entity:HasStatus(OpeRoom.ProjectingStatus)
end

function Severance:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	if not OpeRoom.Contains(entity, entity.Root.Position) then
		return
	end

	local power = self:GetAffinity("Sword") * self:GetLevelScale("Sword")
	local cost = math.clamp(60 * power, 10, 200)
	if OpeRoom.GetStamina(entity) < cost then
		return
	end

	local aim = input.AimPosition
	local target = Hitbox.Closest(Hitbox.Sphere(aim, AIM_RADIUS, entity), aim)
	if not target or not OpeRoom.Contains(entity, target.Root.Position) then
		return
	end

	-- Victim -> os.clock() of this caster's last cut on it. Weak keys: victims that leave
	-- are forgotten on their own.
	local cuts: { [any]: number } = self.Cuts
	if not cuts then
		cuts = setmetatable({}, { __mode = "k" }) :: any
		self.Cuts = cuts
	end
	local now = os.clock()
	if now - (cuts[target] or 0) < VICTIM_COOLDOWN or not OpeRoom.Spend(entity, cost) then
		return
	end
	cuts[target] = now
	if target:HasStatus(COOLDOWN_STATUS) then
		return
	end

	local duration = math.clamp(3 * power, 1, 8)
	target:SetStatus(COOLDOWN_STATUS, true, VICTIM_COOLDOWN)
	self.Services.Status:ApplyStun(target, duration, STATUS)
	target:SetStatus(STATUS, true, duration, true)
end

return Severance
