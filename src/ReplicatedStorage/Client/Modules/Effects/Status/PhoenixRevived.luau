--!strict
--[[
	Phoenix fruit - just hatched from the egg: revival flames on the whole body.
	Status value: the fruit color string. The server keeps it for 5 s.

	Templates: the "PhoenixRevive1" / "PhoenixRevive2" emitters of
	ReplicatedStorage.Assets.Models.Fruits.Phoenix.PhoenixEgg.Phoenixegg, copied onto the
	head, torso and limbs at rate 100 / 20 as in the legacy game.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local RATES: { [string]: number } = {
	PhoenixRevive1 = 100,
	PhoenixRevive2 = 20,
}

return function(character: Model, value: any, _isLocal: boolean): () -> ()
	local egg = EffectAssets.FindFruit("Phoenix", "PhoenixEgg", "Phoenixegg")
	if not egg then
		return function() end
	end

	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	local created: { Instance } = {}
	for name, rate in RATES do
		local template = egg:FindFirstChild(name)
		if not template or not template:IsA("ParticleEmitter") then
			continue
		end
		for _, limbName in LIMBS do
			local limb = character:FindFirstChild(limbName)
			if limb and limb:IsA("BasePart") then
				local emitter = template:Clone()
				if primary and secondary then
					emitter.Color = ColorSequence.new(if name == "PhoenixRevive2" then secondary else primary)
				end
				emitter.Rate = rate
				emitter.Enabled = true
				emitter.Parent = limb
				table.insert(created, emitter)
			end
		end
	end

	return function()
		for _, emitter in created do
			emitter:Destroy()
		end
	end
end
