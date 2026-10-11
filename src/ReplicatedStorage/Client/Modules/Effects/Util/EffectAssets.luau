--!strict
--[[
	Helpers shared by effect modules. Modules in Effects/Util are not loaded as effects.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local EffectAssets = {}

-- Walks ReplicatedStorage.Assets by child names; nil as soon as one is missing.
function EffectAssets.Find(...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

-- Shortcut for Assets.Models.Fruits.<fruit>.<...>.
function EffectAssets.FindFruit(fruitName: string, ...: string): Instance?
	return EffectAssets.Find("Models", "Fruits", fruitName, ...)
end

-- Splits a packed status value "a|b|c" into its fields.
function EffectAssets.Unpack(value: any): { string }
	return if type(value) == "string" then string.split(value, "|") else {}
end

-- Fruit colors from a saved color string, or the given defaults when it is "None".
function EffectAssets.Colors(saved: any, defaultPrimary: Color3, defaultSecondary: Color3): (Color3, Color3)
	local primary, secondary = FruitColor.Parse(if type(saved) == "string" then saved else "")
	if primary and secondary then
		return primary, secondary
	end
	return defaultPrimary, defaultSecondary
end

return EffectAssets
