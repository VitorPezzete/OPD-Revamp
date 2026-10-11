--!strict
--[[
	Gravity fruit - Meteor Shower called: rings of gravity around the caster for a
	second.
	params: { Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Gravity.Power5.GravityRings (a part
	with an Attachment holding a "GravityRingsEffect" emitter).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local EMIT_TIME = 1
local LIFETIME = 3

return function(_origin: Vector3, params: { [string]: any }?)
	local template = EffectAssets.FindFruit("Gravity", "Power5", "GravityRings")
	local caster = params and params.Caster
	if not template or not template:IsA("BasePart") or typeof(caster) ~= "Instance" then
		return
	end
	local root = caster:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	local rings = template:Clone()
	rings.Anchored = false
	rings.CanCollide = false
	rings.CanQuery = false
	rings.CanTouch = false
	rings.Massless = true
	rings.CFrame = root.CFrame

	local primary = FruitColor.Parse(if params and type(params.Colors) == "string" then params.Colors else "")
	local emitters: { ParticleEmitter } = {}
	for _, descendant in rings:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			if primary then
				descendant.Color = ColorSequence.new(primary)
			end
			descendant.Enabled = true
			table.insert(emitters, descendant)
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rings
	weld.Part1 = root
	weld.Parent = rings

	rings.Parent = root

	task.delay(EMIT_TIME, function()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
	end)
	Debris:AddItem(rings, LIFETIME)
end
