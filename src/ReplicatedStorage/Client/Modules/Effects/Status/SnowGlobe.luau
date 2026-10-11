--!strict
--[[
	Snow fruit - Snow Globe: the dome, drawn where it was cast for as long as the caster
	keeps the status, and the map inside it turned to snow.

	Status value: "<x>,<y>,<z>|<radius>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Snow.Power1.SnowGlobe (a part with a
	"Mesh"; mesh scale 1 is a dome 50 studs wide). It fades in from invisible to 0.2
	transparency over 4 s. Without the template a plain ball of the same size is used.

	The snowed map. The legacy server repainted every part inside the dome the moment it
	was cast: snow color (248, 248, 248, or the first fruit color), Plastic material,
	unions forced to their part color and the texture of tree "Leaves" meshes removed.
	Parts of characters (the nearest Model above them holds a Humanoid) were left alone.
	Everything went back when the globe ended. It is only a look, so each client does it
	here on its own copy of the map and the server touches nothing. Parts painted by two
	overlapping globes get their own look back when the last one ends.

	The frozen sea under the globe is a server part (Abilities.Snow["Snow Globe"]).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FADE_TIME = 4
local TRANSPARENCY = 0.2
-- Studs of dome diameter per unit of mesh scale.
local STUDS_PER_SCALE = 50
-- The legacy scan used the mesh scale * 25, the status radius carries 0.25 more.
local RADIUS_PADDING = 0.25
local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)
local LEAVES_NAME = "Leaves"

-- The look a snowed part had before, and how many globes are painting it.
type Snowed = {
	Count: number,
	Color: Color3,
	Material: Enum.Material,
	UsePartColor: boolean?,
	Mesh: SpecialMesh?,
	TextureId: string?,
}

local snowed: { [BasePart]: Snowed } = {}

local function noop() end

local function isCharacterPart(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChild("Humanoid") ~= nil
end

local function paint(part: BasePart, color: Color3)
	local entry = snowed[part]
	if entry then
		entry.Count += 1
	else
		entry = { Count = 1, Color = part.Color, Material = part.Material }
		snowed[part] = entry
		if part:IsA("UnionOperation") then
			entry.UsePartColor = part.UsePartColor
			part.UsePartColor = true
		end
		if part.Name == LEAVES_NAME then
			local mesh = part:FindFirstChild("Mesh")
			if mesh and mesh:IsA("SpecialMesh") then
				entry.Mesh = mesh
				entry.TextureId = mesh.TextureId
				mesh.TextureId = ""
			end
		end
		part.Material = Enum.Material.Plastic
	end
	part.Color = color
end

local function restore(part: BasePart)
	local entry = snowed[part]
	if not entry then
		return
	end
	entry.Count -= 1
	if entry.Count > 0 then
		return
	end
	snowed[part] = nil

	if not part.Parent then
		return
	end
	part.Color = entry.Color
	part.Material = entry.Material
	if entry.UsePartColor ~= nil and part:IsA("UnionOperation") then
		part.UsePartColor = entry.UsePartColor
	end
	if entry.Mesh and entry.TextureId then
		entry.Mesh.TextureId = entry.TextureId
	end
end

-- Paints the map inside the globe; returns the parts it painted.
local function snowMap(center: Vector3, radius: number, color: Color3, dome: BasePart): { BasePart }
	local painted: { BasePart } = {}
	-- Client drawings and ability parts (rings, boulders, the frozen sea) are not the map:
	-- the legacy ones lived inside their caster's character and were skipped with it.
	local skipped: { Instance } = {}
	for _, folder in { World.Effects(), World.Abilities() } do
		if folder ~= Workspace then
			table.insert(skipped, folder)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skipped

	for _, part in Workspace:GetPartBoundsInRadius(center, radius, params) do
		if part == dome or part:IsA("Terrain") then
			continue
		end
		if isCharacterPart(part) then
			continue
		end
		paint(part, color)
		table.insert(painted, part)
	end
	return painted
end

return function(_character: Model, value: any): () -> ()
	local fields = EffectAssets.Unpack(value)
	local coordinates = string.split(fields[1] or "", ",")
	local x, y, z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])
	local radius = tonumber(fields[2])
	if not x or not y or not z or not radius or radius <= 0 then
		return noop
	end
	local primary = FruitColor.Parse(fields[3] or "")

	local dome: BasePart
	local template = EffectAssets.FindFruit("Snow", "Power1", "SnowGlobe")
	if template and template:IsA("BasePart") then
		dome = template:Clone()
		for _, descendant in dome:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		local mesh = dome:FindFirstChildWhichIsA("DataModelMesh")
		if mesh then
			local scale = radius * 2 / STUDS_PER_SCALE
			mesh.Scale = Vector3.new(scale, scale, scale)
		end
		if primary then
			dome.Color = primary
		end
	else
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		ball.Material = Enum.Material.ForceField
		ball.Color = primary or DEFAULT_COLOR
		dome = ball
	end

	dome.Anchored = true
	dome.CanCollide = false
	dome.CanQuery = false
	dome.CanTouch = false
	dome.CastShadow = false
	dome.Transparency = 1
	dome.CFrame = CFrame.new(x, y, z)
	dome.Parent = World.Effects()

	TweenService:Create(dome, TweenInfo.new(FADE_TIME), { Transparency = TRANSPARENCY }):Play()

	local painted = snowMap(Vector3.new(x, y, z), radius - RADIUS_PADDING, primary or DEFAULT_COLOR, dome)

	return function()
		dome:Destroy()
		for _, part in painted do
			restore(part)
		end
	end
end
