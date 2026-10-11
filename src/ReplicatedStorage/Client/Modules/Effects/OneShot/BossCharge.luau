--!strict
--[[
	Fire boss - the flame on its arm while it charges Fire Fist (right arm, 2 s) or Flame
	Pillar (left arm, 4 s).
	params: { Model: Model, Arm: string, Duration: number, Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power2["Flare Fire"] (a part
	holding a "Flare Fire" emitter), welded half a stud below the arm as the legacy
	script did.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Model) ~= "Instance" then
		return
	end
	local arm = (params.Model :: Instance):FindFirstChild(if type(params.Arm) == "string" then params.Arm else "Right Arm")
	local template = EffectAssets.FindFruit("Flare", "Power2", "Flare Fire")
	if not arm or not arm:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return
	end
	local duration: number = if type(params.Duration) == "number" then params.Duration else 2

	local flame = template:Clone()
	flame.Anchored = false
	flame.Massless = true
	flame.CanCollide = false
	flame.CanQuery = false
	flame.CanTouch = false

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if params.Haki then
		primary, secondary = HAKI_COLOR, HAKI_COLOR
	end
	for _, descendant in flame:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = flame
	weld.C1 = CFrame.new(0, 0.5, 0)
	weld.Parent = flame
	flame.Parent = arm
	Debris:AddItem(flame, duration)
end
