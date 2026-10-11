--!strict
--[[
	Hobby fruit - Transform: the glowing ball on the caster's hand while it can turn
	what it touches into a toy, and the caster's arm swing. Purely cosmetic; the reach
	is a server query.

	params: { Caster: Model, Duration: number, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Hobby.Power2.HobbyBall (a part with
	an inner "HobbyBall1" part); both take the fruit's first color when it has custom
	colors.

	The swing is played by the caster's own client only (it replicates from there), at
	8x speed and weight 3 as before. Its clip is not in AnimationConfig: the legacy
	client created the Animation in code.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local ARM_NAME = "Right Arm"
-- Puts the ball on the hand, one stud below the arm's center.
local WELD_C0 = CFrame.new(0, 1, 0)

local SWING_ANIMATION = "rbxassetid://83736181737885"
local SWING_FADE = 0.1
local SWING_WEIGHT = 3
local SWING_SPEED = 8

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if not params or typeof(caster) ~= "Instance" or not caster:IsA("Model") then
		return
	end

	if caster == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			Animations.Play(animator, SWING_ANIMATION, SWING_FADE, SWING_WEIGHT, SWING_SPEED)
		end
	end

	local arm = caster:FindFirstChild(ARM_NAME)
	local template = EffectAssets.FindFruit("Hobby", "Power2", "HobbyBall")
	if not arm or not arm:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return
	end
	local duration: number = if type(params.Duration) == "number" then params.Duration else 0.5

	local ball = template:Clone()
	for _, descendant in ball:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end
	ball.Anchored = false
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Massless = true

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if primary then
		ball.Color = primary
		local inner = ball:FindFirstChild("HobbyBall1")
		if inner and inner:IsA("BasePart") then
			inner.Color = primary
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = ball
	weld.Part1 = arm
	weld.C0 = WELD_C0
	weld.Parent = ball

	ball.CFrame = arm.CFrame * WELD_C0:Inverse()
	ball.Parent = arm
	Debris:AddItem(ball, duration)
end
