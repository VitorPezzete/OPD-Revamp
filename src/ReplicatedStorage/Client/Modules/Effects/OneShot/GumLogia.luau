--!strict
--[[
	Gum fruit - rubber body "the hit bounced off": the body flushes for one second.
	params: { Caster: Model, Colors: string }

	Head, torso and limbs take the first fruit color (the legacy pink, 255 180 180,
	without one). No template: the legacy game only repainted the body. The tint is a
	BodyPaint layer, so the body gets its own color back whatever else painted it
	meanwhile. The server sends this at most once every 1.2 s per character.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DURATION = 1
local DEFAULT_COLOR = Color3.fromRGB(255, 180, 180)

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	local primary = FruitColor.Parse(if type(params and params.Colors) == "string" then (params :: any).Colors else "")

	local release = BodyPaint.Paint(BodyPaint.Limbs(character, LIMBS), { Color = primary or DEFAULT_COLOR })
	task.delay(DURATION, release)
end
