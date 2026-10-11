--!strict
--[[
	Sand fruit passive: a melee / sword hit just passed through the body.
	Status value: the fruit color string. Timed by the server (1 second).

	The six body parts take the sand color (pale yellow unless the fruit has custom
	colors) and shed sand; everything is put back when the status ends.
	Template: ReplicatedStorage.Assets.Models.Fruits.Sand.Logia.SandTrigger (ParticleEmitter).

	The legacy LogiaModule recolored the body on the server and then rebuilt the skin
	from the saved skin color / dye; here the tint is a BodyPaint layer, so the parts get
	their own look back whatever else painted them meanwhile.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(254, 243, 187)

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local primary = FruitColor.Parse(if type(value) == "string" then value else "")
	local template = EffectAssets.FindFruit("Sand", "Logia", "SandTrigger")

	local parts = BodyPaint.Limbs(character, BODY_PARTS)
	local release = BodyPaint.Paint(parts, { Color = primary or DEFAULT_COLOR, Material = Enum.Material.Plastic })

	local emitters: { Instance } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, part in parts do
			local emitter = template:Clone()
			if primary then
				emitter.Color = ColorSequence.new(primary)
			end
			emitter.Enabled = true
			emitter.Parent = part
			table.insert(emitters, emitter)
		end
	end

	return function()
		for _, emitter in emitters do
			emitter:Destroy()
		end
		release()
	end
end
