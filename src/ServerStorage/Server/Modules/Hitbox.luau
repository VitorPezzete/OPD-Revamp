--!strict
--[[
	Server-side hit queries that return combat entities.

	Shapes are tested against the list of tracked characters (at most a few dozen
	players plus the NPCs), not against the world: no spatial query ever walks map
	parts, so even a 200 stud area costs the same as a small one. Each character is
	treated as a sphere of BODY_RADIUS around its root.

	Results are unique, alive and spawned; `exclude` (the caster) is never included.

	`exclude` is also who is asking: a character the caster must leave alone (Allies.Spares:
	the other players of a raid) is not found either, so whatever the caller goes on to do
	to its targets - damage, a stun, a throw - never reaches an ally. A query that looks
	for characters to help (a heal, a buff) passes `friendly` = true and gets them all.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Allies = require(ServerStorage.Server.Modules.Allies)

type CharacterEntity = CharacterEntity.CharacterEntity

local BODY_RADIUS = 2.5

local Hitbox = {}

local function candidates(exclude: CharacterEntity?, friendly: boolean?): () -> CharacterEntity?
	local entities = Knit.GetService("CharacterService"):GetEntities()
	local model: Model? = nil
	return function(): CharacterEntity?
		while true do
			local entity
			model, entity = next(entities, model)
			if not model then
				return nil
			end
			if
				entity ~= exclude
				and not entity.Dead
				and entity.Spawned
				and (friendly or not Allies.Spares(exclude, entity))
			then
				return entity
			end
		end
	end
end

function Hitbox.Sphere(position: Vector3, radius: number, exclude: CharacterEntity?, friendly: boolean?): { CharacterEntity }
	local result: { CharacterEntity } = {}
	local reach = radius + BODY_RADIUS
	for entity in candidates(exclude, friendly) do
		if (entity.Root.Position - position).Magnitude <= reach then
			table.insert(result, entity)
		end
	end
	return result
end

-- Oriented box: `size` is the full extent along the CFrame's axes.
function Hitbox.Box(cframe: CFrame, size: Vector3, exclude: CharacterEntity?, friendly: boolean?): { CharacterEntity }
	local result: { CharacterEntity } = {}
	local half = size / 2 + Vector3.new(BODY_RADIUS, BODY_RADIUS, BODY_RADIUS)
	for entity in candidates(exclude, friendly) do
		local offset = cframe:PointToObjectSpace(entity.Root.Position)
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			table.insert(result, entity)
		end
	end
	return result
end

-- Vertical cylinder (ground areas): within `radius` horizontally and `halfHeight` vertically.
function Hitbox.Cylinder(
	position: Vector3,
	radius: number,
	halfHeight: number,
	exclude: CharacterEntity?,
	friendly: boolean?
): { CharacterEntity }
	local result: { CharacterEntity } = {}
	local reach = radius + BODY_RADIUS
	for entity in candidates(exclude, friendly) do
		local offset = entity.Root.Position - position
		if math.abs(offset.Y) <= halfHeight + BODY_RADIUS and Vector3.new(offset.X, 0, offset.Z).Magnitude <= reach then
			table.insert(result, entity)
		end
	end
	return result
end

-- Box in front of a character: centered `distance` studs ahead of the root, facing the same way.
function Hitbox.InFront(entity: CharacterEntity, size: Vector3, distance: number): { CharacterEntity }
	return Hitbox.Box(entity.Root.CFrame * CFrame.new(0, 0, -distance), size, entity)
end

-- Closest entity to a point among the results, if any.
function Hitbox.Closest(entities: { CharacterEntity }, position: Vector3): CharacterEntity?
	local closest: CharacterEntity? = nil
	local closestDistance = math.huge
	for _, entity in entities do
		local distance = (entity.Root.Position - position).Magnitude
		if distance < closestDistance then
			closest, closestDistance = entity, distance
		end
	end
	return closest
end

return Hitbox
