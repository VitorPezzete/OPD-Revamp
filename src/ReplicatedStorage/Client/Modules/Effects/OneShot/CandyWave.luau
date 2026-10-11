--!strict
--[[
	Candy fruit - Syrup Wave: the wave in flight. Cosmetic copy of a box the server sweeps
	in a straight line (it goes through walls, as the legacy part did).

	params: { Direction: Vector3, Speed: number, Lifetime: number, Scale: number,
	          Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Candy.Power5.CandyWave, sized
	45 x 5 x 15 times Scale as the legacy script did (X across the flight).

	First fruit color on the wave; dark with armament haki.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local SIZE = Vector3.new(45, 5, 15)
local MIN_SCALE = 0.02

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local speed = params.Speed
	local lifetime = params.Lifetime
	local scale = params.Scale
	if typeof(direction) ~= "Vector3" or type(speed) ~= "number" or type(lifetime) ~= "number" or type(scale) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or speed <= 0 or lifetime <= 0 or scale < MIN_SCALE then
		return
	end

	local template = EffectAssets.FindFruit("Candy", "Power5", "CandyWave")
	if not template or not template:IsA("BasePart") then
		return
	end

	local wave = template:Clone()
	for _, descendant in wave:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") or descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end
	wave.Size = SIZE * scale
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if params.Haki then
		wave.Color = HAKI_COLOR
	elseif primary then
		wave.Color = primary
	end

	local unit = direction.Unit
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local start = CFrame.lookAt(origin, origin + unit, up)
	wave.CFrame = start
	wave.Parent = World.Effects()

	TweenService:Create(wave, TweenInfo.new(lifetime, Enum.EasingStyle.Linear), {
		CFrame = start + unit * speed * lifetime,
	}):Play()
	Debris:AddItem(wave, lifetime)
end
