--!strict
--[[
	Snow fruit - Snow Body. Status value: the fruit color string.

	The head, torso and limbs turn white (the "White" BrickColor the legacy server wrote
	in the Body Colors, or the BrickColor closest to the first fruit color: Body Colors
	only hold palette colors) and shed snow: a copy
	of ReplicatedStorage.Assets.Models.Fruits.Snow.Power2.SnowTrigger (a ParticleEmitter)
	in each of them, tinted with the second fruit color. The white is a BodyPaint layer,
	so the parts get their own color back whatever else painted them meanwhile.

	The legacy server rewrote the character's Body Colors and restored them from the
	saved skin; here nothing is changed on the server, so there is nothing to restore
	wrongly (skin dye, another body effect).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(242, 243, 243)

return function(character: Model, value: any): () -> ()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local template = EffectAssets.FindFruit("Snow", "Power2", "SnowTrigger")

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local release = BodyPaint.Paint(limbs, {
		Color = if primary then BrickColor.new(primary).Color else DEFAULT_COLOR,
	})

	local emitters: { Instance } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, limb in limbs do
			local emitter = template:Clone()
			if secondary then
				emitter.Color = ColorSequence.new(secondary)
			end
			emitter.Enabled = true
			emitter.Parent = limb
			table.insert(emitters, emitter)
		end
	end

	return function()
		release()
		for _, emitter in emitters do
			emitter:Destroy()
		end
	end
end
