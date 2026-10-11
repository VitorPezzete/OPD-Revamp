--!strict
--[[
	Barrier fruit - Slam: the slab that shoots out of the caster. Purely cosmetic; the
	server samples the same easing curve to decide who it hits.

	origin: where the slab starts (2 studs behind the caster).
	params: { Direction: Vector3 (unit), Side: number, Thickness: number, Travel: number,
	          TweenSeconds: number, Lifetime: number, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Barrier.Power2.BarrierSlam (a part);
	a plain translucent slab when it is missing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(170, 170, 220)
local FALLBACK_TRANSPARENCY = 0.24

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local side = params.Side
	if typeof(direction) ~= "Vector3" or type(side) ~= "number" or direction.Magnitude < 1e-3 or side <= 0 then
		return
	end
	local thickness: number = if type(params.Thickness) == "number" then params.Thickness else 5
	local travel: number = if type(params.Travel) == "number" then params.Travel else 100
	local tweenSeconds: number = if type(params.TweenSeconds) == "number" then params.TweenSeconds else 1.5
	local lifetime: number = if type(params.Lifetime) == "number" then params.Lifetime else 1.2

	local template = EffectAssets.FindFruit("Barrier", "Power2", "BarrierSlam")
	local slab: BasePart
	if template and template:IsA("BasePart") then
		slab = template:Clone()
		-- The legacy template carried its (server) touch-damage script.
		for _, descendant in slab:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	else
		local part = Instance.new("Part")
		part.Material = Enum.Material.Plastic
		part.Transparency = FALLBACK_TRANSPARENCY
		part.Color = DEFAULT_COLOR
		slab = part
	end

	slab.Anchored = true
	slab.CanCollide = false
	slab.CanQuery = false
	slab.CanTouch = false
	slab.Size = Vector3.new(side, side, thickness)

	local saved = params.Colors
	if type(saved) == "string" and saved ~= "None" then
		slab.Color = EffectAssets.Colors(saved, slab.Color, slab.Color)
	end

	local unit = direction.Unit
	local start = if math.abs(unit.Y) > 0.999
		then CFrame.lookAt(origin, origin + unit, Vector3.xAxis)
		else CFrame.lookAt(origin, origin + unit)
	slab.CFrame = start
	slab.Parent = World.Effects()

	TweenService:Create(slab, TweenInfo.new(tweenSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = start * CFrame.new(0, 0, -travel),
	}):Play()
	Debris:AddItem(slab, lifetime)
end
