--!strict
--[[
	Chilly fruit - Ice Wave: five ice spikes bursting out one after the other from the
	caster towards the aim. Purely cosmetic; the server hurts whoever is inside the same
	boxes without any instance.

	origin: the caster's position when the wave was released.
	params: { Direction: Vector3 (unit), BaseSize: number, Count: number, Interval: number,
	          Lifetime: number, Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Chilly.Power5.ChillySpikes (a MeshPart).

	Spike i is a cube of side BaseSize * i, centered half its side further along the
	direction than the previous center, popping from nothing to full size in 0.2 s.
	With custom colors the spikes fade from the first color to the second along the row;
	with armament haki they are dark.

	The wave animation belongs to Effects.Status.ChillyWaveCharging (played on release).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_TIME = 0.2
local START_SIZE = Vector3.new(0.01, 0.01, 0.01)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local baseSize = params.BaseSize
	if typeof(direction) ~= "Vector3" or type(baseSize) ~= "number" then
		return
	end
	if direction.Magnitude < 1e-3 or baseSize <= 0 then
		return
	end
	local count: number = if type(params.Count) == "number" then params.Count else 5
	local interval: number = if type(params.Interval) == "number" then params.Interval else 0.2
	local lifetime: number = if type(params.Lifetime) == "number" then params.Lifetime else 3

	local template = EffectAssets.FindFruit("Chilly", "Power5", "ChillySpikes")
	if not template or not template:IsA("BasePart") then
		return
	end

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local unit = direction.Unit
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis

	local center = origin
	for index = 1, count do
		local length = baseSize * index
		center += unit * (length / 2)

		local spike = template:Clone()
		for _, descendant in spike:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		spike.Anchored = true
		spike.CanCollide = false
		spike.CanQuery = false
		spike.CanTouch = false
		spike.Size = START_SIZE
		spike.CFrame = CFrame.lookAt(center, center + unit, up)

		if params.Haki then
			spike.Color = HAKI_COLOR
		elseif primary and secondary then
			spike.Color = primary:Lerp(secondary, if count > 1 then (index - 1) / (count - 1) else 0)
		end

		spike.Parent = World.Effects()
		TweenService:Create(spike, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(length, length, length),
		}):Play()
		Debris:AddItem(spike, lifetime)

		if index < count then
			task.wait(interval)
		end
	end
end
