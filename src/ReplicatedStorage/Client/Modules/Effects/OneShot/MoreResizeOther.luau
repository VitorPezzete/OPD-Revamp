--!strict
--[[
	More fruit - Resize Other: the ball on the caster's right hand while its touch can
	resize other characters, and the caster's arm swing. Cosmetic only; the server
	decides who is touched.
	params: { Duration: number, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.More.Power2.MoreBall (a part with an
	inner "HobbyBall1" part). It keeps its own green: the legacy game never tinted this
	ball with the fruit colors.

	The swing is played by the caster's own client only (it replicates from there), at
	8x speed and weight 3 as before. Its clip is not in AnimationConfig: the legacy
	client created the Animation in code.

	(The legacy client could ask for the left hand; nothing used it, the right is kept.)
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local LIMB = "Right Arm"
-- Legacy weld: the ball sits one stud below the arm's centre, on the hand.
local HAND_OFFSET = CFrame.new(0, 1, 0)
local DEFAULT_DURATION = 0.5

local SWING_ANIMATION = "rbxassetid://106525931147996"
local SWING_FADE = 0.1
local SWING_WEIGHT = 3
local SWING_SPEED = 8

local function soften(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if typeof(caster) ~= "Instance" then
		return
	end

	if caster == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			Animations.Play(animator, SWING_ANIMATION, SWING_FADE, SWING_WEIGHT, SWING_SPEED)
		end
	end

	local limb = caster:FindFirstChild(LIMB)
	local template = EffectAssets.FindFruit("More", "Power2", "MoreBall")
	if not limb or not limb:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return
	end

	local duration: number = if params and type(params.Duration) == "number" then params.Duration else DEFAULT_DURATION

	local ball = template:Clone()
	soften(ball)
	for _, descendant in ball:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			soften(descendant)
		end
	end

	ball.CFrame = limb.CFrame * HAND_OFFSET:Inverse()

	local weld = Instance.new("Weld")
	weld.Part0 = ball
	weld.Part1 = limb
	weld.C0 = HAND_OFFSET
	weld.Parent = ball

	ball.Parent = limb
	Debris:AddItem(ball, duration)
end
