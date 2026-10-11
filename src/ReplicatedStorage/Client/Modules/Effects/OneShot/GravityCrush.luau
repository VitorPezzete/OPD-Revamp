--!strict
--[[
	Gravity fruit - Crushing Force released: ten shockwaves, one every 0.15 s.
	params: { Size: number (final mesh scale), Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Gravity.Power4.GravityShockwave (a
	part with a "Mesh" inside).

	`origin` is one stud under the caster's root at release. Each wave grows from its
	authored mesh scale to `Size` on every axis over 0.4 s while fading out.

	Not ported: the ring the legacy client drew around the user while charging
	(ReplicatedStorage.Resources.GravityCrush, sized from the client's own charge
	counter): the charge is only known to the server now.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local WAVES = 10
local WAVE_INTERVAL = 0.15
local WAVE_TIME = 0.4
local WAVE_LIFETIME = 0.75

return function(origin: Vector3, params: { [string]: any }?)
	local template = EffectAssets.FindFruit("Gravity", "Power4", "GravityShockwave")
	if not params or not template or not template:IsA("BasePart") then
		return
	end
	local size: number = if type(params.Size) == "number" then math.max(params.Size, 0.01) else 4.5
	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local tweenInfo = TweenInfo.new(WAVE_TIME, Enum.EasingStyle.Linear)

	task.spawn(function()
		for _ = 1, WAVES do
			local wave = template:Clone()
			wave.Anchored = true
			wave.CanCollide = false
			wave.CanQuery = false
			wave.CanTouch = false
			if primary then
				wave.Color = primary
			end
			wave.CFrame = wave.CFrame.Rotation + origin
			wave.Parent = World.Effects()

			local mesh = wave:FindFirstChildWhichIsA("DataModelMesh")
			if mesh then
				TweenService:Create(mesh, tweenInfo, { Scale = Vector3.new(size, size, size) }):Play()
			end
			TweenService:Create(wave, tweenInfo, { Transparency = 1 }):Play()
			Debris:AddItem(wave, WAVE_LIFETIME)

			task.wait(WAVE_INTERVAL)
		end
	end)
end
