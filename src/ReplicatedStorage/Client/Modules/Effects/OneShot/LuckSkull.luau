--!strict
--[[
	Luck fruit - Coin throw, when the coin comes up skull: a giant skull flashes over
	the target.
	origin: 20 studs above the target.   params: only Caster / Colors.
	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power5.Skull (MeshPart with an
	inner part "Inside").

	Both grow from nothing to their full size in one second (legacy sizes) and are gone
	when they get there. The skull takes the fruit's second color, or red.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local LIFETIME = 1
local SKULL_SIZE = Vector3.new(75.447, 83.569, 76.237)
local INSIDE_SIZE = Vector3.new(75, 83, 76)
local DEFAULT_COLOR = Color3.fromRGB(255, 0, 0)
local INSIDE_COLOR = Color3.fromRGB(0, 0, 0)

local function ghost(part: BasePart, position: Vector3)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = Vector3.zero
	part.Position = position
end

return function(origin: Vector3, params: { [string]: any }?)
	local template = EffectAssets.FindFruit("Luck", "Power5", "Skull")
	if not template or not template:IsA("BasePart") then
		return
	end

	local _, secondary = EffectAssets.Colors(params and params.Colors, DEFAULT_COLOR, DEFAULT_COLOR)
	local info = TweenInfo.new(LIFETIME, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

	local skull = template:Clone()
	ghost(skull, origin)
	skull.Color = secondary

	local inside = skull:FindFirstChild("Inside")
	if inside and inside:IsA("BasePart") then
		ghost(inside, origin)
		inside.Color = INSIDE_COLOR
		TweenService:Create(inside, info, { Size = INSIDE_SIZE, Transparency = 0.75 }):Play()
	end

	skull.Parent = World.Effects()
	Debris:AddItem(skull, LIFETIME)
	TweenService:Create(skull, info, { Size = SKULL_SIZE, Transparency = 0.5 }):Play()
end
