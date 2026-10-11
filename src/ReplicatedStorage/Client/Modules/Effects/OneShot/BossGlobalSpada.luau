--!strict
--[[
	Raid bosses (Bosses/_Global) - Sand: the line of blades.
	params: { Direction: Vector3 (unit), Base: number (length of the first blade),
	          Count: number, Interval: number (seconds between two blades),
	          StandSeconds: number, Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Sand.Power4.SandSpada (MeshPart).

	`origin` is the boss's root. Unlike a player's Desert Spada there is one row only and
	the blades come out one after the other: the i-th is Base * i long and tall, centred
	half its length past the previous one. Each grows in 0.25 s, stands StandSeconds,
	then shrinks and fades over 1.5 s, as in the legacy boss script.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local THICKNESS = 0.2
local MAX_BLADES = 12
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local GROW_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SHRINK_INFO = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local START_SIZE = Vector3.new(THICKNESS, 0.01, 0.01)
local END_SIZE = Vector3.new(THICKNESS, 0.1, 0.1)
local SHRINK_SECONDS = 1.75

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Direction) ~= "Vector3" or type(params.Base) ~= "number" then
		return
	end
	local direction: Vector3 = params.Direction
	local base: number = params.Base
	if direction.Magnitude < 1e-3 or base <= 0 then
		return
	end
	direction = direction.Unit
	local count: number = if type(params.Count) == "number" then math.clamp(math.floor(params.Count), 1, MAX_BLADES) else 7
	local interval: number = if type(params.Interval) == "number" then math.max(params.Interval, 0) else 0.05
	local standSeconds: number = if type(params.StandSeconds) == "number" then math.max(params.StandSeconds, 0) else 2

	local template = EffectAssets.FindFruit("Sand", "Power4", "SandSpada")
	if not template or not template:IsA("BasePart") then
		return
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color: Color3? = if params.Haki then HAKI_COLOR else primary
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis

	local center = origin
	for index = 1, count do
		local length = base * index
		center += direction * (length / 2)

		local blade = template:Clone()
		for _, descendant in blade:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		blade.Anchored = true
		blade.CanCollide = false
		blade.CanQuery = false
		blade.CanTouch = false
		if color then
			blade.Color = color
		end
		blade.Size = START_SIZE
		blade.CFrame = CFrame.lookAt(center, center + direction, up)
		blade.Parent = World.Effects()

		TweenService:Create(blade, GROW_INFO, { Size = Vector3.new(THICKNESS, length, length) }):Play()
		task.delay(standSeconds, function()
			if blade.Parent then
				TweenService:Create(blade, SHRINK_INFO, { Size = END_SIZE, Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(blade, standSeconds + SHRINK_SECONDS)

		if interval > 0 and index < count then
			task.wait(interval)
		end
	end
end
