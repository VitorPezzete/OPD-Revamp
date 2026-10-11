--!strict
--[[
	Barrier fruit - shared bookkeeping of the one construct (Wall, Room or Prison) a
	character can have standing. Not an ability: the leading underscore keeps it apart
	from the modules AbilityService looks up by ability name.

	The legacy game kept every barrier in one folder per player and emptied it whenever
	a new one was made; the sibling abilities do the same through this module, since
	they cannot see each other's objects.

	A construct is two things:
	- Collision: invisible anchored parts created here. This is the one place the fruit
	  puts instances on the server, because other players have to be physically stopped.
	  Nothing visual is on them.
	- Look: the replicated "BarrierConstruct" status, drawn by every client
	  (Effects.Status.BarrierConstruct). Value:
	  "<kind>|px|py|pz|lx|ly|lz|sx|sy|sz|<fruit colors>".

	"BarrierActive" is the legacy flag of the same name: replicated while the user holds
	any barrier up (a standing construct, a Slam in flight, the Barrier Body). Its owner
	keeps the crossed-fingers pose for as long as it is set (Effects.Status.BarrierActive).
	Constructs set and clear it here; Slam and Barrier Body call SetActive / ClearActive.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local World = require(ReplicatedStorage.Shared.Util.World)

type CharacterEntity = CharacterEntity.CharacterEntity

export type Kind = "Wall" | "Room" | "Prison"

type Record = {
	Kind: Kind,
	Token: number,
	Parts: { Instance },
}

local STATUS = "BarrierConstruct"
local ACTIVE_STATUS = "BarrierActive"
-- Engine limit of a part's extent.
local MAX_EXTENT = 2048

local Construct = {}

Construct.MaxExtent = MAX_EXTENT
-- The legacy game refused every Barrier key while its user was stunned (DF_Disabled).
Construct.StunStatus = "Stunned"

local records: { [CharacterEntity]: Record } = setmetatable({}, { __mode = "k" }) :: any
local lastToken = 0

-- Orientation from a facing direction. Clients rebuild it the same way from the status.
function Construct.Frame(position: Vector3, look: Vector3): CFrame
	if look.Magnitude < 1e-3 then
		return CFrame.new(position)
	end
	local unit = look.Unit
	if math.abs(unit.Y) > 0.999 then
		return CFrame.lookAt(position, position + unit, Vector3.xAxis)
	end
	return CFrame.lookAt(position, position + unit)
end

local function prepare(part: BasePart, cframe: CFrame, size: Vector3)
	part.Name = "BarrierCollision"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = World.Abilities()
end

-- One solid slab.
function Construct.Block(cframe: CFrame, size: Vector3): { Instance }
	local part = Instance.new("Part")
	prepare(part, cframe, size)
	return { part }
end

-- Hollow box made of slabs (used when the authored hollow mesh is not available).
function Construct.Shell(cframe: CFrame, size: Vector3, thickness: number, floor: boolean): { Instance }
	local parts: { Instance } = {}
	local half = size / 2
	local inset = thickness / 2

	local function slab(offset: Vector3, slabSize: Vector3)
		local part = Instance.new("Part")
		prepare(part, cframe * CFrame.new(offset), slabSize)
		table.insert(parts, part)
	end

	slab(Vector3.new(half.X - inset, 0, 0), Vector3.new(thickness, size.Y, size.Z))
	slab(Vector3.new(-(half.X - inset), 0, 0), Vector3.new(thickness, size.Y, size.Z))
	slab(Vector3.new(0, 0, half.Z - inset), Vector3.new(size.X, size.Y, thickness))
	slab(Vector3.new(0, 0, -(half.Z - inset)), Vector3.new(size.X, size.Y, thickness))
	slab(Vector3.new(0, half.Y - inset, 0), Vector3.new(size.X, thickness, size.Z))
	if floor then
		slab(Vector3.new(0, -(half.Y - inset), 0), Vector3.new(size.X, thickness, size.Z))
	end
	return parts
end

-- Collision copy of an authored hollow part (union / mesh), stripped and invisible.
function Construct.FromTemplate(template: BasePart, cframe: CFrame, size: Vector3): { Instance }
	local part = template:Clone()
	part:ClearAllChildren()
	prepare(part, cframe, size)
	return { part }
end

local function findFruitAsset(...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- ReplicatedStorage.Assets.Models.Fruits.Barrier.<...>, if it is a part.
function Construct.FindTemplate(...: string): BasePart?
	local found = findFruitAsset("Barrier", ...)
	return if found and found:IsA("BasePart") then found else nil
end

--[[
	The Prison cage. The legacy place kept it in ReplicatedStorage.Resources, so it was
	migrated to Fruits._Shared instead of the fruit's own Power3 folder. _Shared holds two
	parts of that name: the cage is the union that takes a color (the other one is a grey
	copy with box collision, which would be a solid block here).
]]
function Construct.FindPrison(): BasePart?
	local own = Construct.FindTemplate("Power3", "BarrierPrison")
	if own then
		return own
	end

	local shared = findFruitAsset("_Shared")
	local fallback: BasePart? = nil
	if shared then
		for _, child in shared:GetChildren() do
			if child.Name == "BarrierPrison" and child:IsA("BasePart") then
				if child:IsA("PartOperation") and child.UsePartColor then
					return child
				end
				fallback = fallback or child
			end
		end
	end
	return fallback
end

-- Raises the BarrierActive flag, for `duration` seconds or until ClearActive.
function Construct.SetActive(entity: CharacterEntity, duration: number?)
	entity:SetStatus(ACTIVE_STATUS, true, duration, true)
end

function Construct.ClearActive(entity: CharacterEntity)
	entity:ClearStatus(ACTIVE_STATUS)
end

function Construct.Get(entity: CharacterEntity): Kind?
	local record = records[entity]
	return if record then record.Kind else nil
end

function Construct.IsCurrent(entity: CharacterEntity, token: number): boolean
	local record = records[entity]
	return record ~= nil and record.Token == token
end

-- Removes the standing construct. With `kind`, only if it is of that kind.
function Construct.Clear(entity: CharacterEntity, kind: Kind?)
	local record = records[entity]
	if not record or (kind and record.Kind ~= kind) then
		return
	end

	records[entity] = nil
	for _, part in record.Parts do
		part:Destroy()
	end
	entity:ClearStatus(STATUS)
	Construct.ClearActive(entity)
end

-- Replaces whatever was standing. Returns a token for delayed work (expiry timers).
function Construct.Set(
	entity: CharacterEntity,
	kind: Kind,
	cframe: CFrame,
	size: Vector3,
	colors: string,
	parts: { Instance }
): number
	Construct.Clear(entity)

	lastToken += 1
	records[entity] = { Kind = kind, Token = lastToken, Parts = parts }

	local position, look = cframe.Position, cframe.LookVector
	entity:SetStatus(
		STATUS,
		string.format(
			"%s|%.2f|%.2f|%.2f|%.4f|%.4f|%.4f|%.2f|%.2f|%.2f|%s",
			kind,
			position.X,
			position.Y,
			position.Z,
			look.X,
			look.Y,
			look.Z,
			size.X,
			size.Y,
			size.Z,
			colors
		),
		nil,
		true
	)
	Construct.SetActive(entity)
	return lastToken
end

return Construct
