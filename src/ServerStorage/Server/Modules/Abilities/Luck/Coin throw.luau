--!strict
--[[
	Luck fruit - Coin throw: flips a coin at whatever is aimed at; one time in six it
	comes up skull.

	Cost:    10 luck, taken FIRST as in the legacy game: a throw with nothing under the
	         aim, out of range or during the 2 s cooldown still pays.
	Target:  the character on the aimed line (Shared.AimTarget, the legacy auto target);
	         without one, whatever the aim rests on - a character, or any part of the
	         map, in which case the coin flies to the centre of that part, as the legacy
	         coin did. It must be less than 300 studs away.
	Coin:    homes on the target at 150 studs/s and always arrives; a stun of the
	         caster does not stop a coin already thrown, as before.
	Roll:    1-6 on arrival (4-6 while lucky).
	         6      a giant skull drops on the target; a character takes
	                clamp(its max health / 4 * sniper affinity,
	                      1500 * sniper affinity, 15000), "Special", not dodgeable
	         other  +10 * sniper affinity luck, whatever the coin was thrown at

	Like the other Luck powers it had no "powers disabled" check in the legacy game: it
	can be used while stunned (the seal gate of AbilityService still applies).

	Like Alice's cards, the coin cannot miss, so the server only waits the flight time
	(the distance at the throw, less the 5 studs at which the legacy coin counted as
	arrived, at 150 studs/s). Effects.OneShot.LuckCoin draws the coin and
	Effects.OneShot.LuckSkull the skull.

	Legacy problems fixed here:
	- The client sent the target part; the server ran a Heartbeat connection per coin
	  that errored every frame once the target was gone.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "LuckCoin"
local SKULL_EFFECT = "LuckSkull"

local COST = 10
local COOLDOWN = 2
local MAX_RANGE = 300
-- The auto target had no range of its own; the 300 studs are checked afterwards.
local AIM_RANGE = 1000
-- How far past the aim point the ray that finds what it rests on goes.
local AIM_PROBE = 2
local SPEED = 150
local ARRIVAL_DISTANCE = 5
local SKULL_FACE = 6
local HEALTH_FRACTION = 0.25
local MIN_DAMAGE = 1500
local MAX_DAMAGE = 15000
local LUCK_GAIN = 10
local SKULL_HEIGHT = 20

local CoinThrow = Ability.extend()
-- The legacy script never checked for disabled powers: a seal does not stop it.
CoinThrow.IgnoreSeal = true

CoinThrow.KeepThroughStun = true

local function land(self: any, target: CharacterEntity?, point: Vector3, epoch: number)
	if self.Epoch ~= epoch then
		return
	end
	local entity: CharacterEntity = self.Entity
	local sniper = self:GetAffinity("Sniper")

	if Shared.RollDie(entity) ~= SKULL_FACE then
		Shared.Add(entity, LUCK_GAIN * sniper)
		return
	end

	local alive = target ~= nil and not target.Dead and target.Spawned and target.Model.Parent ~= nil
	local position = if target and alive then target.Root.Position else point
	self:PlayEffect(SKULL_EFFECT, position + Vector3.new(0, SKULL_HEIGHT, 0))
	if target and alive then
		local damage = math.clamp(target.MaxHealth * HEALTH_FRACTION * sniper, MIN_DAMAGE * sniper, MAX_DAMAGE)
		self:Damage(target, damage, "Special", EFFECT, false)
	end
end

function CoinThrow:OnBegin(input: Ability.AbilityInput)
	local entity: CharacterEntity = self.Entity
	if Shared.Get(entity) < COST then
		return
	end
	Shared.Add(entity, -COST)

	local origin = entity.Root.Position
	local target: CharacterEntity? = Shared.AimTarget(entity, input.AimPosition, AIM_RANGE)
	local point: Vector3
	if target then
		point = target.Root.Position
	else
		-- What the aim rests on.
		local offset = input.AimPosition - origin
		if offset.Magnitude < 0.05 then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { entity.Model }
		local result = Workspace:Raycast(origin, offset.Unit * (offset.Magnitude + AIM_PROBE), params)
		if not result then
			return
		end
		local owner: CharacterEntity? = self.Services.Character:GetEntityFromPart(result.Instance)
		-- Found by its own ray, not by Hitbox: an ally (Allies.Spares) is not a target,
		-- the coin just lands where it was aimed.
		if owner and owner ~= entity and not owner.Dead and owner.Spawned and not Allies.Spares(entity, owner) then
			target = owner
			point = owner.Root.Position
		else
			point = result.Instance.Position
		end
	end

	local distance = (point - origin).Magnitude
	if distance >= MAX_RANGE then
		return
	end

	local now = os.clock()
	if now - (self.LastThrow or -COOLDOWN) < COOLDOWN then
		return
	end
	self.LastThrow = now
	self:StartCooldown(COOLDOWN)

	self:PlayEffect(EFFECT, origin, {
		Target = if target then target.Model else nil,
		Point = point,
		Speed = SPEED,
	})

	self.Epoch = self.Epoch or 0
	task.delay(math.max(distance - ARRIVAL_DISTANCE, 0) / SPEED, land, self, target, point, self.Epoch)
end

function CoinThrow:OnInterrupt()
	-- Coins still in flight are lost.
	self.Epoch = (self.Epoch or 0) + 1
end

return CoinThrow
