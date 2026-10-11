--!strict
--[[
	Slash fruit - library shared by its four abilities. NOT an ability: AbilityService only
	requires modules named after an ability in FruitConfig.

	Factor:  sword affinity * (sword level / cap), the scaling term of every Slash formula.
	Haki:    armament haki doubles a cut and turns it into "Haki" damage.
	Fly:     a flying blade. The legacy game spawned a part pushed by a BodyVelocity with a
	         Touched connection; here the blade is a box swept forward in short steps and
	         tested against the tracked characters only (Hitbox), so it costs nothing on
	         the map and cannot tunnel: each step covers the whole stretch flown since the
	         previous one. Like the legacy part it ignores walls, hits each character once
	         and never its owner. Blades in flight vanish when the ability is interrupted
	         (ability.Epoch).
	Aim:     where a charged blade starts. A fully charged one aimed near a character close
	         enough appears 25 studs in front of that character instead of at the hand.
	         The legacy client picked that character with its auto-aim (AimModule): the
	         one closest to the mouse ray within min(fov / (distance along the ray + 10),
	         20) degrees, fov being 750 at charge 100 and 500 below. The same cone is
	         tested here, from the caster's root towards the validated aim point (the
	         server has no camera).
	Meshes:  the ten Dismantle meshes have different shapes (upright, flat, diagonal):
	         DismantleSize reads the hitbox of the one the server picked from the asset.

	Every blade hit carries the tag "Slash" (DamageModifiers.ChopSlashImmunity).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

export type Blade = {
	Origin: Vector3,
	-- Unit vector.
	Direction: Vector3,
	Speed: number,
	Lifetime: number,
	-- X: width across the flight, Y: height, Z: depth along the flight.
	Size: Vector3,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Dodgeable: boolean,
	OnHit: ((target: CharacterEntity) -> ())?,
}

local STEP = 0.05
local HAKI_MULTIPLIER = 2
-- Legacy: charged blades appeared 10 studs ahead of the hand, or 25 before a locked target.
local SPAWN_AHEAD = 10
local LOCK_DISTANCE = 25
-- Auto-aim cone of the legacy AimModule.
local LOCK_FOV = 500
local LOCK_FOV_FULL = 750
local LOCK_FULL_CHARGE = 100
local LOCK_MAX_ANGLE = 20
local LOCK_FOV_OFFSET = 10
local LOCK_MIN_DISTANCE = 0.5

local SlashShared = {}

SlashShared.Tag = "Slash"
-- Written by Passives.Slash, read by Slash Frenzy (non-replicated).
SlashShared.FrenzyBornStatus = "SlashFrenzyBorn"
SlashShared.FrenzyKillsStatus = "SlashFrenzyKills"

-- (sword affinity * sword level / cap, sword affinity)
function SlashShared.Factor(ability: any): (number, number)
	local affinity: number = ability:GetAffinity("Sword")
	return affinity * ability:GetLevelScale("Sword"), affinity
end

-- 1 + BuffWeapons perk / 100.
function SlashShared.WeaponBuff(ability: any): number
	return 1 + ability.Context.Data.Data.Expertise.Perks.BuffWeapons.Value / 100
end

-- (damage multiplier, damage trait, armament haki on)
function SlashShared.Haki(ability: any): (number, CombatTypes.DamageTrait, boolean)
	if ability.Services.Haki:IsArmamentActive(ability.Entity) then
		return HAKI_MULTIPLIER, "Haki", true
	end
	return 1, "Special", false
end

-- Flight direction: from the root to the aim point, as in the legacy game.
function SlashShared.Direction(entity: CharacterEntity, aim: Vector3): Vector3
	local offset = aim - entity.Root.Position
	if offset.Magnitude < 0.05 then
		return entity.Root.CFrame.LookVector
	end
	return offset.Unit
end

function SlashShared.HandPosition(entity: CharacterEntity): Vector3
	local arm = entity.Model:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return arm.Position
	end
	return entity.Root.Position
end

-- The character within `range` studs closest to the aimed line, inside the auto-aim cone.
local function findLock(entity: CharacterEntity, aim: Vector3, fov: number, range: number): CharacterEntity?
	local apex = entity.Root.Position
	local toAim = aim - apex
	local reach = toAim.Magnitude
	if reach < 0.05 then
		return nil
	end
	local look = toAim.Unit

	local best: CharacterEntity? = nil
	local bestAngle = LOCK_MAX_ANGLE
	for _, target in Hitbox.Sphere(apex, range, entity) do
		local offset = target.Root.Position - apex
		local distance = offset.Magnitude
		if distance > range or distance < 0.05 then
			continue
		end
		local radians = math.acos(math.clamp(look:Dot(offset.Unit), -1, 1))
		local angle = math.deg(radians)
		local along = math.clamp(distance * math.cos(radians), LOCK_MIN_DISTANCE, reach)
		if angle <= math.min(fov / (along + LOCK_FOV_OFFSET), LOCK_MAX_ANGLE) and angle < bestAngle then
			best, bestAngle = target, angle
		end
	end
	return best
end

local dismantleSizes: { Vector3 }? = nil

-- Hitbox (width, height, depth) of the `variant`-th Dismantle mesh, the meshes being
-- sorted by name as the clients sort them; `fallback` without the asset. The meshes are
-- authored sideways: their X axis is the flight direction.
function SlashShared.DismantleSize(variant: number, fallback: Vector3): Vector3
	local sizes = dismantleSizes
	if not sizes then
		local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
		for _, name in { "Models", "Fruits", "Slash", "Power2" } do
			current = if current then current:FindFirstChild(name) else nil
		end
		local meshes: { BasePart } = {}
		if current then
			for _, child in current:GetChildren() do
				if child:IsA("BasePart") then
					table.insert(meshes, child)
				end
			end
		end
		table.sort(meshes, function(a: BasePart, b: BasePart)
			return a.Name < b.Name
		end)
		local read: { Vector3 } = {}
		for _, mesh in meshes do
			table.insert(read, Vector3.new(mesh.Size.Z, mesh.Size.Y, mesh.Size.X))
		end
		dismantleSizes = read
		sizes = read
	end
	if #sizes == 0 then
		return fallback
	end
	return sizes[(variant - 1) % #sizes + 1]
end

-- Returns (origin, direction, locked on a character). `charge` (0-100) widens the cone.
function SlashShared.Aim(ability: any, aim: Vector3, canLock: boolean, lockRange: number, charge: number): (Vector3, Vector3, boolean)
	local entity: CharacterEntity = ability.Entity
	local direction = SlashShared.Direction(entity, aim)

	if canLock then
		local fov = if charge >= LOCK_FULL_CHARGE then LOCK_FOV_FULL else LOCK_FOV
		local target = findLock(entity, aim, fov, lockRange)
		if target then
			return target.Root.Position - direction * LOCK_DISTANCE, direction, true
		end
	end

	local hand = SlashShared.HandPosition(entity)
	local forward = aim - hand
	local ahead = if forward.Magnitude < 0.05 then direction else forward.Unit
	return hand + ahead * SPAWN_AHEAD, direction, false
end

function SlashShared.Fly(ability: any, blade: Blade)
	local entity: CharacterEntity = ability.Entity
	local epoch = ability.Epoch or 0
	local started = os.clock()
	local travelled = 0
	local hit: { [CharacterEntity]: boolean } = {}

	-- lookAt is undefined for a vertical look vector with the default up axis.
	local up = if math.abs(blade.Direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local orientation = CFrame.lookAt(blade.Origin, blade.Origin + blade.Direction, up)

	local function step()
		if (ability.Epoch or 0) ~= epoch or entity.Dead then
			return
		end

		local elapsed = math.min(os.clock() - started, blade.Lifetime)
		local reached = elapsed * blade.Speed
		local center = orientation * CFrame.new(0, 0, -(travelled + reached) / 2)
		local size = Vector3.new(blade.Size.X, blade.Size.Y, reached - travelled + blade.Size.Z)
		travelled = reached

		for _, target in Hitbox.Box(center, size, entity) do
			if not hit[target] then
				hit[target] = true
				ability:Damage(target, blade.Damage, blade.Trait, SlashShared.Tag, blade.Dodgeable)
				if blade.OnHit then
					blade.OnHit(target)
				end
			end
		end

		if elapsed < blade.Lifetime then
			task.delay(STEP, step)
		end
	end
	step()
end

return SlashShared
