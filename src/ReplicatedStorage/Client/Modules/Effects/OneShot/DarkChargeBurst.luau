--!strict
--[[
	Dark fruit - Dark Charge released: the darkness jumps to everyone it hit and clings
	to their root for a second.
	params: { Targets: { Model }, Duration: number, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Dark.Power1.DarkChargePart.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Targets) ~= "table" then
		return
	end
	local template = EffectAssets.FindFruit("Dark", "Power1", "DarkChargePart")
	if not template or not template:IsA("BasePart") then
		return
	end

	local duration: number = if type(params.Duration) == "number" then params.Duration else 1
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	for _, model in params.Targets do
		-- A target that is not streamed in to this client arrives as nil / a hole.
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			continue
		end

		local part = template:Clone()
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = root.CFrame
		if primary and secondary then
			for _, descendant in part:GetDescendants() do
				if descendant:IsA("ParticleEmitter") then
					descendant.Color = FruitColor.ToSequence(primary, secondary)
				end
			end
		end

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = root
		weld.Parent = part

		part.Parent = root
		Debris:AddItem(part, duration)
	end
end
