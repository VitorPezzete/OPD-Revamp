--!strict
--[[
	Blood fruit - helpers shared by its abilities (not an ability: no FruitConfig entry
	has this name, so AbilityService never loads it as one).

	Every Blood ability is paid for with the user's own health and gives health back
	when it hurts someone. "Blood Concentrate" doubles both the price and the refund;
	siblings learn about it through the BloodConcentrate status, never through objects.

	The legacy script subtracted / added health directly, with no mitigation. That is
	kept: the cost is not an attack, so it does not go through CombatService (shield,
	resist perks and defense experience do not apply to it).

	Targeting (Hemomancy, Supernova). The legacy client aimed these by itself: its
	AimModule took the character closest to the camera-to-mouse line inside a cone of
	750 / (distance + 10) degrees, 20 at most, so the cursor only had to be near someone.
	FindTarget is that cone run on the server, from the caster towards the validated aim
	point (the server has no camera), tried after a character standing on the aim point.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local BloodShared = {}

BloodShared.ConcentrateStatus = "BloodConcentrate"

-- A character this close to the aim point is aimed at, whatever the cone says.
local AIM_RADIUS = 6
local CONE_FOV = 750
local CONE_PADDING = 10
local CONE_MAX_ANGLE = 20

function BloodShared.IsConcentrated(entity: CharacterEntity): boolean
	return entity:HasStatus(BloodShared.ConcentrateStatus)
end

-- Multiplier Concentrate puts on costs, heals, damage, ranges and sizes.
function BloodShared.GetScale(entity: CharacterEntity): number
	return if BloodShared.IsConcentrated(entity) then 2 else 1
end

-- Takes `percent` of max health from the user (doubled while concentrated). Can kill.
function BloodShared.PayHealth(entity: CharacterEntity, percent: number)
	local amount = math.floor(entity.MaxHealth * percent / 100 * BloodShared.GetScale(entity))
	if amount > 0 then
		entity:TakeDamage(amount)
	end
end

-- Gives health back to the user (doubled while concentrated).
function BloodShared.Heal(entity: CharacterEntity, amount: number)
	if entity.Dead then
		return
	end
	local heal = math.floor(amount * BloodShared.GetScale(entity))
	if heal > 0 then
		entity:Heal(heal)
	end
end

-- The character the user is aiming at, no further than `range` studs from it (see the header).
function BloodShared.FindTarget(entity: CharacterEntity, aimPosition: Vector3, range: number): CharacterEntity?
	local origin = entity.Root.Position

	local direct = Hitbox.Closest(Hitbox.Sphere(aimPosition, AIM_RADIUS, entity), aimPosition)
	if direct and (direct.Root.Position - origin).Magnitude <= range then
		return direct
	end

	local aim = aimPosition - origin
	local aimDistance = aim.Magnitude
	if aimDistance < 1e-3 then
		return nil
	end
	local direction = aim / aimDistance

	local best: CharacterEntity? = nil
	local bestAngle = CONE_MAX_ANGLE
	for _, candidate in Hitbox.Sphere(origin, range, entity) do
		local offset = candidate.Root.Position - origin
		local distance = offset.Magnitude
		if distance < 1e-3 or distance > range then
			continue
		end

		local cosine = math.clamp(direction:Dot(offset) / distance, -1, 1)
		local angle = math.deg(math.acos(cosine))
		-- The cone is measured where the target stands along the aim line, never past the aim point.
		local along = math.clamp(distance * cosine, 0.5, math.max(aimDistance, 0.5))
		if angle < bestAngle and angle <= CONE_FOV / (along + CONE_PADDING) then
			best, bestAngle = candidate, angle
		end
	end
	return best
end

return BloodShared
