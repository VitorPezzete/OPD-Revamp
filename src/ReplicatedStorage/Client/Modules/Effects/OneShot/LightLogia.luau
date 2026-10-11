--!strict
--[[
	Light fruit - logia pass-through: a melee or sword hit went through the body.
	params: { Caster: Model (the logia user), Colors: string }
	Templates: ReplicatedStorage.Assets.Models.Fruits.Light.Logia.LightTrigger (a
	ParticleEmitter) and PointLight.

	For one second the head, torso and limbs turn the color of light (first fruit color,
	yellow by default), sparkle and glow. The tint is a BodyPaint layer, so the body gets
	its own look back whatever else painted it meanwhile. The legacy server rewrote Body
	Colors from the saved skin instead, and skipped the effect while a body ability was
	painting the body; the server already skips it for the ported ones, the attributes
	are checked again here for late arrivals.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 0)
local DURATION = 1
local BODY_ATTRIBUTES = { "MagmaBody", "CandyBody", "SnowBody", "VenomBody", "Gum2nd" }

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	for _, attribute in BODY_ATTRIBUTES do
		if character:GetAttribute(attribute) then
			return
		end
	end

	local emitterTemplate = EffectAssets.FindFruit("Light", "Logia", "LightTrigger")
	local lightTemplate = EffectAssets.FindFruit("Light", "Logia", "PointLight")
	local primary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local release = BodyPaint.Paint(limbs, { Color = primary or DEFAULT_COLOR, Material = Enum.Material.Plastic })

	local added: { Instance } = {}
	for _, limb in limbs do
		if emitterTemplate and emitterTemplate:IsA("ParticleEmitter") then
			local emitter = emitterTemplate:Clone()
			if primary then
				-- The legacy code used the first color at both ends of the sequence.
				emitter.Color = ColorSequence.new(primary)
			end
			emitter.Enabled = true
			emitter.Parent = limb
			table.insert(added, emitter)
		end
		if lightTemplate and lightTemplate:IsA("PointLight") then
			local light = lightTemplate:Clone()
			if primary then
				light.Color = primary
			end
			light.Enabled = true
			light.Parent = limb
			table.insert(added, light)
		end
	end

	task.delay(DURATION, function()
		release()
		for _, instance in added do
			instance:Destroy()
		end
	end)
end
