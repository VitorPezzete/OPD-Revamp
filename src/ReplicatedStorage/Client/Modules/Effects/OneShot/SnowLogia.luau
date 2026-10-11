--!strict
--[[
	Snow fruit - logia "the hit passed through": the body bursts into snow for one second.
	params: { Caster: Model, Colors: string }

	Head, torso and limbs turn snow white (or the first fruit color) and each sheds snow
	from a copy of ReplicatedStorage.Assets.Models.Fruits.Snow.Logia.SnowTrigger (a
	ParticleEmitter, tinted with both fruit colors). The tint is a BodyPaint layer, so the
	body gets its own color back whatever else painted it meanwhile. The server sends this
	at most once every 1.2 s per character.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DURATION = 1
local DEFAULT_COLOR = Color3.fromRGB(248, 248, 248)

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end

	local primary, secondary =
		FruitColor.Parse(if type(params and params.Colors) == "string" then (params :: any).Colors else "")
	local template = EffectAssets.FindFruit("Snow", "Logia", "SnowTrigger")

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local release = BodyPaint.Paint(limbs, { Color = primary or DEFAULT_COLOR })

	local emitters: { Instance } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, limb in limbs do
			local emitter = template:Clone()
			if primary and secondary then
				emitter.Color = FruitColor.ToSequence(primary, secondary)
			end
			emitter.Enabled = true
			emitter.Parent = limb
			table.insert(emitters, emitter)
		end
	end

	task.delay(DURATION, function()
		release()
		for _, emitter in emitters do
			emitter:Destroy()
		end
	end)
end
