--!strict
--[[
	Light fruit - helpers shared by its abilities (not an ability: AbilityService only
	loads modules by ability name).

	Every beam of the fruit is an instant ray on the server: where it starts (a fixed
	point beside the root instead of the animated arm of the legacy code), the armament
	haki rule (double damage, "Haki" trait) and the ray itself live here.
]]
local Workspace = game:GetService("Workspace")

local Shared = {}

-- Statuses the abilities use to see each other (sibling objects are not visible).
Shared.BEAM_STATUS = "LightBeam"
Shared.JEWELS_STATUS = "LightJewels"
-- Replicated while the owner must keep facing its aim (Effects.Status.LightAiming).
Shared.AIM_STATUS = "LightAiming"

local HAKI_MULTIPLIER = 2
-- Legacy: arm position + arm look vector. The arm hangs 1.5 studs beside the root.
local HAND_OFFSET = Vector3.new(1.5, 0.5, -1)

-- Point the beams leave from. `left` mirrors it (Sacred Jewels alternates hands).
function Shared.HandOrigin(entity: any, left: boolean?): Vector3
	local offset = if left then Vector3.new(-HAND_OFFSET.X, HAND_OFFSET.Y, HAND_OFFSET.Z) else HAND_OFFSET
	return entity.Root.CFrame:PointToWorldSpace(offset)
end

-- Unit direction from origin to the aim point; the look vector when they coincide
-- (the legacy `.Unit` of a zero vector was NaN).
function Shared.Direction(entity: any, origin: Vector3, aim: Vector3): Vector3
	local offset = aim - origin
	if offset.Magnitude < 0.05 then
		return entity.Root.CFrame.LookVector
	end
	return offset.Unit
end

-- Armament haki doubles every Light damage and turns it into "Haki" damage.
function Shared.Haki(ability: any, amount: number): (number, "Haki" | "Special", boolean)
	if ability.Services.Haki:IsArmamentActive(ability.Entity) then
		return amount * HAKI_MULTIPLIER, "Haki", true
	end
	return amount, "Special", false
end

function Shared.RayParams(entity: any): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	return params
end

-- Where a beam of `distance` studs ends: the first thing it touches, or its full length.
function Shared.Cast(entity: any, origin: Vector3, direction: Vector3, distance: number): Vector3
	if distance <= 0 then
		return origin
	end
	local result = Workspace:Raycast(origin, direction * distance, Shared.RayParams(entity))
	return if result then result.Position else origin + direction * distance
end

return Shared
