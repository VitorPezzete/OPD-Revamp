--!strict
--[[
	Luck fruit - Slot Machine jackpot (triple seven). Status value: the fruit color string.

	The jackpot particles burst from the character's root for as long as it lasts.
	Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power1.Jackpot (an Attachment
	holding ParticleEmitters), painted with the fruit's first color, or orange.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 136, 0)

local function noop() end

return function(character: Model, value: any): () -> ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = EffectAssets.FindFruit("Luck", "Power1", "Jackpot")
	if not root or not root:IsA("BasePart") or not template then
		return noop
	end

	local primary = EffectAssets.Colors(value, DEFAULT_COLOR, DEFAULT_COLOR)

	local effect = template:Clone()
	effect.Name = "LuckJackpot"
	for _, emitter in effect:GetDescendants() do
		if emitter:IsA("ParticleEmitter") then
			emitter.Color = ColorSequence.new(primary)
		end
	end
	effect.Parent = root

	return function()
		effect:Destroy()
	end
end
