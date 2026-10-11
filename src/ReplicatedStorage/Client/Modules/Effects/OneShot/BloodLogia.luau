--!strict
--[[
	Blood fruit - logia pass-through: a melee or sword hit went through the body, which
	turns to blood for a second.

	params: { Caster: Model, Colors: string, Duration: number }
	Template: ReplicatedStorage.Assets.Models.Fruits.Blood.Power4.Body (a folder of
	emitters; one copy of each goes on each of the six body parts, as authored: the one
	that is off in the template stays off).

	The six body parts also take the first fruit color (blood red without one) for that
	second. The tint is a BodyPaint layer, so the body gets its own color back whatever
	else painted it meanwhile. The server sends this at most once every 1.2 s per
	character.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(255, 47, 47)

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Caster) ~= "Instance" then
		return
	end
	local character: Instance = params.Caster
	local duration: number = if type(params.Duration) == "number" then params.Duration else 1

	local folder = EffectAssets.FindFruit("Blood", "Power4", "Body")
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local sequence = if primary and secondary then FruitColor.ToSequence(primary, secondary) else nil

	local parts = BodyPaint.Limbs(character, BODY_PARTS)
	local release = BodyPaint.Paint(parts, { Color = primary or DEFAULT_COLOR })

	if folder then
		for _, part in parts do
			for _, template in folder:GetChildren() do
				if template:IsA("ParticleEmitter") then
					local emitter = template:Clone()
					if sequence then
						emitter.Color = sequence
					end
					emitter.Parent = part
					Debris:AddItem(emitter, duration)
				end
			end
		end
	end

	task.delay(duration, release)
end
