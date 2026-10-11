--!strict
--[[
	Blood fruit - Blood Concentrate: the aura around the body while the mode is on.
	Status value: the fruit color string ("None" keeps the authored colors).
	Template: ReplicatedStorage.Assets.Models.Fruits.Blood.Power6.Concentrate (ParticleEmitter).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local function noop() end

return function(character: Model, value: any): () -> ()
	local template = EffectAssets.FindFruit("Blood", "Power6", "Concentrate")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not template or not template:IsA("ParticleEmitter") or not root then
		return noop
	end

	local emitter = template:Clone()
	local primary, secondary = FruitColor.Parse(if type(value) == "string" then value else "")
	if primary and secondary then
		emitter.Color = FruitColor.ToSequence(primary, secondary)
	end
	emitter.Enabled = true
	emitter.Parent = root

	return function()
		emitter:Destroy()
	end
end
