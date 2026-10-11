--!strict
--[[
	Venom fruit - Poison Coat. Status value: the fruit color string.

	The head, torso and limbs take the color of the poison and drip it: a copy of
	ReplicatedStorage.Assets.Models.Fruits.Venom.Power2.VenomHydraCharge (a
	ParticleEmitter) in each of them. Colors, as in the legacy game:
	- body: first fruit color, dark indigo by default (bright red with Venom Demon);
	- drops: both fruit colors (swapped with Venom Demon), purple by default (dull red
	  with Venom Demon);
	- everything dark while armament haki is on.
	Repainted when haki or Venom Demon is switched. The body color is a BodyPaint layer,
	so the parts get their own color back whatever else painted them meanwhile.

	The legacy server rewrote the character's Body Colors and restored them from the
	saved skin; here nothing is changed on the server, so there is nothing to restore
	wrongly (skin dye, another body effect).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local BodyPaint = require(script.Parent.Parent.Util.BodyPaint)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local HAKI_ATTRIBUTE = "Haki"
local DEMON_ATTRIBUTE = "VenomDemon"

local HAKI_BODY = Color3.fromRGB(25, 12, 25)
local HAKI_DROPS = Color3.fromRGB(26, 13, 26)
local DEFAULT_BODY = BrickColor.new("Dark indigo").Color
local DEMON_BODY = BrickColor.new("Bright red").Color
local DEFAULT_DROPS = Color3.fromRGB(77, 26, 114)
local DEMON_DROPS = Color3.fromRGB(163, 75, 75)

return function(character: Model, value: any): () -> ()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local template = EffectAssets.FindFruit("Venom", "Power2", "VenomHydraCharge")

	local limbs = BodyPaint.Limbs(character, LIMBS)
	local emitters: { ParticleEmitter } = {}
	if template and template:IsA("ParticleEmitter") then
		for _, limb in limbs do
			local emitter = template:Clone()
			emitter.Enabled = true
			emitter.Parent = limb
			table.insert(emitters, emitter)
		end
	end

	-- Body color and drops for the current haki / Venom Demon state.
	local function colors(): (Color3, ColorSequence)
		local demon = character:GetAttribute(DEMON_ATTRIBUTE)
		if character:GetAttribute(HAKI_ATTRIBUTE) then
			return HAKI_BODY, ColorSequence.new(HAKI_DROPS)
		elseif primary and secondary then
			if demon then
				return primary, FruitColor.ToSequence(secondary, primary)
			end
			return primary, FruitColor.ToSequence(primary, secondary)
		elseif demon then
			return DEMON_BODY, ColorSequence.new(DEMON_DROPS)
		end
		return DEFAULT_BODY, ColorSequence.new(DEFAULT_DROPS)
	end

	local release, repaint = BodyPaint.Paint(limbs, { Color = (colors()) })

	local function paint()
		local body, drops = colors()
		repaint({ Color = body })
		for _, emitter in emitters do
			emitter.Color = drops
		end
	end

	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
	local demonConnection = character:GetAttributeChangedSignal(DEMON_ATTRIBUTE):Connect(paint)

	return function()
		hakiConnection:Disconnect()
		demonConnection:Disconnect()
		release()
		for _, emitter in emitters do
			emitter:Destroy()
		end
	end
end
