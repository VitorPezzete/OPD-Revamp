--!strict
--[[
	Chilly boss - the frost on its hand while it winds up Ice Wave (0.6 s).
	params: { Model: Model, Arm: string, Duration: number, Haki: boolean, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Chilly.Power5.ChillyFreezeEffect (a
	part with an "Attachment.Freeze" emitter), welded on the arm at its authored size.

	The player's Ice Wave grows the same part from nothing over 3 s of charge
	(Effects.Status.ChillyWaveCharging); the boss shows it whole for its short wind-up.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_SEQUENCE = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Model) ~= "Instance" then
		return
	end
	local arm = (params.Model :: Instance):FindFirstChild(if type(params.Arm) == "string" then params.Arm else "Right Arm")
	local template = EffectAssets.FindFruit("Chilly", "Power5", "ChillyFreezeEffect")
	if not arm or not arm:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return
	end
	local duration: number = if type(params.Duration) == "number" then params.Duration else 0.6

	local frost = template:Clone()
	for _, descendant in frost:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	frost.Anchored = false
	frost.Massless = true
	frost.CanCollide = false
	frost.CanQuery = false
	frost.CanTouch = false
	frost.CFrame = arm.CFrame

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local emitter = frost:FindFirstChild("Freeze", true)
	if params.Haki then
		frost.Color = HAKI_COLOR
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Color = HAKI_SEQUENCE
		end
	elseif primary and secondary then
		frost.Color = primary
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = frost
	weld.Part1 = arm
	weld.Parent = frost
	frost.Parent = arm
	Debris:AddItem(frost, duration)
end
