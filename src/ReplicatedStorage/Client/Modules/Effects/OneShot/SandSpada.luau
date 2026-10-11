--!strict
--[[
	Sand fruit - Desert Spada, the line of blades.
	params: { Direction: Vector3 (unit), Base: number (length of the first blade),
	          Haki: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Sand.Power4.SandSpada (MeshPart).

	`origin` is the caster's root. Two rows of 7 blades, as in the legacy game: the i-th
	blade of the first row is Base * i long and tall, of the second row (Base - 5) * i
	(skipped when that is not positive); each is centred half its length past the
	previous one of its row. They grow in 0.25 s and, 2 seconds after the cast, shrink
	and fade for a quarter of a second before being removed.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BLADES = 7
local THICKNESS = 0.2
local SECOND_ROW_OFFSET = 5
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local GROW_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SHRINK_INFO = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local START_SIZE = Vector3.new(THICKNESS, 0.01, 0.01)
local END_SIZE = Vector3.new(THICKNESS, 0.1, 0.1)
local STAND_SECONDS = 2
local SHRINK_SECONDS = 0.25

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Direction) ~= "Vector3" or type(params.Base) ~= "number" then
		return
	end
	local direction: Vector3 = params.Direction
	if direction.Magnitude < 1e-3 then
		return
	end
	direction = direction.Unit

	local template = EffectAssets.FindFruit("Sand", "Power4", "SandSpada")
	if not template or not template:IsA("BasePart") then
		return
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local color: Color3? = if params.Haki then HAKI_COLOR else primary

	local blades: { BasePart } = {}
	for _, base in { params.Base, params.Base - SECOND_ROW_OFFSET } do
		if base <= 0 then
			continue
		end

		local center = origin
		for index = 1, BLADES do
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
			blade.CFrame = CFrame.lookAt(center, center + direction)
			blade.Parent = World.Effects()

			TweenService:Create(blade, GROW_INFO, { Size = Vector3.new(THICKNESS, length, length) }):Play()
			table.insert(blades, blade)
		end
	end

	task.delay(STAND_SECONDS, function()
		for _, blade in blades do
			TweenService:Create(blade, SHRINK_INFO, { Size = END_SIZE, Transparency = 1 }):Play()
		end
		task.wait(SHRINK_SECONDS)
		for _, blade in blades do
			blade:Destroy()
		end
	end)
end
