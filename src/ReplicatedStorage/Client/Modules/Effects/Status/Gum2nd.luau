--!strict
--[[
	Gum fruit - 2nd Gear. Status value: the fruit color string.

	- Steam: ReplicatedStorage.Assets.Models.Fruits.Gum.Power4.Gum2nd (a ParticleEmitter)
	  on the torso.
	- Skin: head, torso and limbs take the first fruit color, or "Pastel orange" without
	  custom colors (the legacy flushed skin).

	The legacy server rewrote the character's Body Colors and later rebuilt them from the
	saved skin / skin dye. Here each client tints the parts itself through a BodyPaint
	layer, so nothing has to know about skins and the parts get their own colors back
	whatever else painted them while the gear was on.
]]
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BODY_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local DEFAULT_SKIN = BrickColor.new("Pastel orange").Color

return function(character: Model, value: any): () -> ()
	local skin = EffectAssets.Colors(value, DEFAULT_SKIN, DEFAULT_SKIN)
	local release = BodyPaint.Paint(BodyPaint.Limbs(character, BODY_PARTS), { Color = skin })

	local steam: ParticleEmitter? = nil
	local template = EffectAssets.FindFruit("Gum", "Power4", "Gum2nd")
	local torso = character:FindFirstChild("Torso")
	if template and template:IsA("ParticleEmitter") and torso then
		local emitter = template:Clone()
		emitter.Enabled = true
		emitter.Parent = torso
		steam = emitter
	end

	return function()
		if steam then
			steam:Destroy()
		end
		release()
	end
end
