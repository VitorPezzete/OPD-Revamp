--!strict
--[[
	Snow fruit - Snow Ring, while the key is held: a see-through preview of the ring,
	shown to the owner only (the legacy server part was invisible to everyone else too).

	Status value: "<size>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Snow.Power6.SnowRing (a union, long
	axis X, stood upright here).

	The preview sits mostly buried, as the legacy one did, where the server will raise
	the ring on release: at the aim point (InputController, the point the release will
	send) when that point is inside the owner's Snow Globe (read from the character's
	"SnowGlobe" attribute), around the owner otherwise.
	First fruit color, or dark when the key was pressed with armament haki on.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GLOBE_ATTRIBUTE = "SnowGlobe"
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local PREVIEW_TRANSPARENCY = 0.7
-- How much of the buried preview sticks out of the ground.
local VISIBLE_HEIGHT = 1.5
local FEET_OFFSET = 3
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function noop() end

local function getGlobe(character: Model): (Vector3?, number?)
	local fields = EffectAssets.Unpack(character:GetAttribute(GLOBE_ATTRIBUTE))
	local coordinates = string.split(fields[1] or "", ",")
	local x, y, z = tonumber(coordinates[1]), tonumber(coordinates[2]), tonumber(coordinates[3])
	local radius = tonumber(fields[2])
	if not x or not y or not z or not radius then
		return nil, nil
	end
	return Vector3.new(x, y, z), radius
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local fields = EffectAssets.Unpack(value)
	local size = tonumber(fields[1])
	local template = EffectAssets.FindFruit("Snow", "Power6", "SnowRing")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not size or size <= 0 or not template or not template:IsA("BasePart") then
		return noop
	end
	if not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local root: BasePart = foundRoot

	local preview = template:Clone()
	for _, descendant in preview:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	preview.Anchored = true
	preview.CanCollide = false
	preview.CanQuery = false
	preview.CanTouch = false
	preview.Transparency = PREVIEW_TRANSPARENCY
	preview.Size = Vector3.new(size, size / 2, size / 2)
	local primary = FruitColor.Parse(fields[2] or "")
	if character:GetAttribute(HAKI_ATTRIBUTE) then
		preview.Color = HAKI_COLOR
	elseif primary then
		preview.Color = primary
	end

	local inputController = Knit.GetController("InputController")

	local buried = size / 2 - VISIBLE_HEIGHT
	local function place()
		local position = root.Position - Vector3.new(0, FEET_OFFSET + buried, 0)

		local globeCenter, globeRadius = getGlobe(character)
		if globeCenter and globeRadius then
			local aim: Vector3 = inputController:GetAimPosition()
			if (aim - globeCenter).Magnitude <= globeRadius then
				position = aim - Vector3.new(0, buried, 0)
			end
		end
		preview.CFrame = CFrame.new(position) * UPRIGHT
	end

	place()
	preview.Parent = World.Effects()
	local connection = RunService.RenderStepped:Connect(place)

	return function()
		connection:Disconnect()
		preview:Destroy()
	end
end
