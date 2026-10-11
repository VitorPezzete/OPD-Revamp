--!strict
--[[
	Luck fruit - the 5 s "lucky moment" after Fortune's Purge broke a seal.
	Status value: the fruit color string.

	Same particles as the jackpot, in the fruit's second color, or green.
	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power1.Jackpot (an Attachment
	holding ParticleEmitters).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(0, 213, 0)

local function noop() end

return function(character: Model, value: any): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Luck", "Power1", "Jackpot")
	if not root or not root:IsA("BasePart") or not template then
		return noop
	end

	local _, secondary = EffectAssets.Colors(value, DEFAULT_COLOR, DEFAULT_COLOR)

	local effect = template:Clone()
	effect.Name = "LuckMoment"
	for _, emitter in effect:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Color = ColorSequence.new(secondary)
		end
	end
	effect.Parent = root

	return function()
		effect:Destroy()
	end
end
