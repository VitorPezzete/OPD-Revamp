--!strict
--[[
	Flare fruit - logia pass-through: a melee or sword hit went through the body.
	params: { Caster: Model (the logia user), Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Logia.FlareFire (a ParticleEmitter).

	For one second the head, torso and limbs turn the color of fire (first fruit color,
	orange by default) and burn. The tint is a BodyPaint layer, so the body gets its own
	look back whatever else painted it meanwhile. The legacy server rewrote Body Colors
	from the saved skin instead, and skipped the effect while a body ability was painting
	the body (Magma Body is the only ported one).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DEFAULT_COLOR = Color3.fromRGB(255, 176, 0)
local DURATION = 1
local BODY_ATTRIBUTE = "MagmaBody"

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	if character:GetAttribute(BODY_ATTRIBUTE) then
		return
	end

	local template = EffectAssets.FindFruit("Flare", "Logia", "FlareFire")
	local primary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local release = BodyPaint.Paint(limbs, { Color = primary or DEFAULT_COLOR, Material = Enum.Material.Plastic })

	local fires: { Instance } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, limb in limbs do
			local clone = template:Clone()
			if primary then
				-- The legacy code used the first color at both ends of the sequence.
				clone.Color = ColorSequence.new(primary)
			end
			clone.Enabled = true
			clone.Parent = limb
			table.insert(fires, clone)
		end
	end

	task.delay(DURATION, function()
		release()
		for _, fire in fires do
			fire:Destroy()
		end
	end)
end
