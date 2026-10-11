--!strict
--[[
	Chilly fruit - logia "the hit passed through": the body turns to ice for one second.
	params: { Caster: Model, Colors: string }

	Head, torso and limbs become Foil in the first fruit color (default icy blue). The
	tint is a BodyPaint layer, so the body gets its own look back whatever else painted
	it meanwhile. The server sends this at most once every 1.2 s per character.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DURATION = 1
local DEFAULT_COLOR = Color3.fromRGB(128, 187, 219)

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	local color = FruitColor.Parse(if type(params and params.Colors) == "string" then (params :: any).Colors else "")
		or DEFAULT_COLOR

	local release = BodyPaint.Paint(BodyPaint.Limbs(character, LIMBS), { Color = color, Material = Enum.Material.Foil })
	task.delay(DURATION, release)
end
