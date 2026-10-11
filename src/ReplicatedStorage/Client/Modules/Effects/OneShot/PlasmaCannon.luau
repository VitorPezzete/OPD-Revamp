--!strict
--[[
	Plasma fruit - Plasma Cannon, one ray of the volley.
	origin: the sphere in the left hand. params: { Target: Vector3, Burst: Vector3?
	(where the server placed the blast: the middle of the last segment of its own roll of
	the ray), Haki: boolean, Size: number (sniper affinity), Thickness: number,
	Colors: string, Caster: Model }

	A jagged ray that stays whole for a second (the legacy shrink tween was commented
	out), and a burst on its last segment for 0.25 s, drawn where the server hits:
	ReplicatedStorage.Assets.Models.Fruits.Plasma.Power4.PlasmaBurst (a part with a
	BillboardGui holding a "Background" image), scaled by Size.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.PlasmaBolt)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local DEFAULT_COLOR = Color3.fromRGB(221, 117, 255)
local RAY_LIFE = 1
local BURST_LIFE = 0.25

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	if not params or typeof(target) ~= "Vector3" then
		return
	end

	local color = DEFAULT_COLOR
	if params.Haki then
		color = HAKI_COLOR
	elseif type(params.Colors) == "string" then
		color = FruitColor.Parse(params.Colors) or DEFAULT_COLOR
	end

	local last = drawBolt(origin, {
		Target = target,
		Color = color,
		Thickness = params.Thickness,
		Jitter = 2,
		Life = RAY_LIFE,
	})

	local template = EffectAssets.FindFruit("Plasma", "Power4", "PlasmaBurst")
	if not template or not template:IsA("BasePart") then
		return
	end

	local burst = template:Clone()
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.CanTouch = false
	burst.Size = template.Size * (if type(params.Size) == "number" then params.Size else 1)
	burst.CFrame = if typeof(params.Burst) == "Vector3" then CFrame.new(params.Burst) else last or CFrame.new(target)

	local billboard = burst:FindFirstChildOfClass("BillboardGui")
	local background = billboard and billboard:FindFirstChild("Background")
	if background and background:IsA("ImageLabel") then
		background.ImageColor3 = color
	end

	burst.Parent = World.Effects()
	Debris:AddItem(burst, BURST_LIFE)
end
