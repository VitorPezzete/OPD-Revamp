--!strict
--[[
	Dark fruit - a hit negated by the Dark user's other fruit: darkness smokes off the
	body for one second.
	params: { Caster: Model, Colors: string }

	Head, torso and limbs each get a copy of
	ReplicatedStorage.Assets.Models.Fruits.Dark.Logia.Smoke (a Smoke, tinted with the
	first fruit color). The body is not repainted here: the other fruit's own
	pass-through effect does that (see Passives.Dark).
	The server sends this at most once every 1.2 s per character.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LIMBS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local DURATION = 1

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local template = EffectAssets.FindFruit("Dark", "Logia", "Smoke")
	if not template or not template:IsA("Smoke") then
		return
	end

	local primary = FruitColor.Parse(if type(params and params.Colors) == "string" then (params :: any).Colors else "")

	for _, limbName in LIMBS do
		local limb = character:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			local smoke = template:Clone()
			if primary then
				smoke.Color = primary
			end
			smoke.Enabled = true
			smoke.Parent = limb
			Debris:AddItem(smoke, DURATION)
		end
	end
end
