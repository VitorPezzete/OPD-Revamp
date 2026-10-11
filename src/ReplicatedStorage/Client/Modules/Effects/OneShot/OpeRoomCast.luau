--!strict
--[[
	Ope fruit - Room, the cast: the "CreateRoom" clip (over-weighted, as in the legacy)
	played the moment the key is released, and, when the Room is not fully charged, the
	mini room held in the left hand during the one second wind-up: it appears 0.2 s after
	the release and is gone 0.8 s later, when the real Room opens around the caster.
	Only the caster's own client plays the clip (the Animator replicates it); everyone
	draws the mini room.

	params: { Mini: boolean, Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Ope.Power1.MiniOpe (a small sphere
	with its inner shell "MeshPart" and a "Wind" disc welded to it). A fruit color pair
	paints the two spheres with the first color and the wind with the second.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ANIMATION_FADE = 0.1
local ANIMATION_WEIGHT = 3

local MINI_DELAY = 0.2
local MINI_LIFETIME = 0.8
local ARM_NAME = "Left Arm"
local ARM_OFFSET = CFrame.new(0, -0.5, 1)
local WIND_TILT = CFrame.Angles(80.1, 0, 0)
-- Radians per second: the legacy fed its "degrees" straight to CFrame.Angles.
local WIND_SPIN = -180

local function showMini(caster: Model, colors: any)
	local template = EffectAssets.FindFruit("Ope", "Power1", "MiniOpe")
	local arm = caster:FindFirstChild(ARM_NAME)
	if not template or not template:IsA("BasePart") or not arm or not arm:IsA("BasePart") then
		return
	end

	local mini = template:Clone()
	local shell = mini:FindFirstChild("MeshPart")
	local wind = mini:FindFirstChild("Wind")
	local windWeld = (if wind then wind:FindFirstChildWhichIsA("Weld") else nil) :: Weld?

	for _, descendant in mini:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	mini.Anchored = false
	mini.CanCollide = false
	mini.CanQuery = false
	mini.CanTouch = false
	mini.Massless = true

	local primary, secondary = FruitColor.Parse(if type(colors) == "string" then colors else "")
	if primary and secondary then
		mini.Color = primary
		if shell and shell:IsA("BasePart") then
			shell.Color = primary
		end
		if wind and wind:IsA("BasePart") then
			wind.Color = secondary
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = mini
	weld.C0 = ARM_OFFSET
	weld.Parent = mini
	mini.Parent = arm

	local connection: RBXScriptConnection? = nil
	if windWeld then
		local spinning = windWeld
		spinning.C0 = WIND_TILT
		local angle = 0
		connection = RunService.Heartbeat:Connect(function(deltaTime: number)
			angle += WIND_SPIN * deltaTime
			spinning.C1 = CFrame.Angles(0, angle, 0)
		end)
	end

	task.delay(MINI_LIFETIME, function()
		if connection then
			connection:Disconnect()
		end
		mini:Destroy()
	end)
end

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if typeof(caster) ~= "Instance" or not caster:IsA("Model") then
		return
	end

	local animator = if caster == Players.LocalPlayer.Character then Animations.FindAnimator(caster) else nil
	if animator then
		local track = Animations.Get(animator, AnimationConfig.FruitAnims.CreateRoom)
		track.Looped = false
		track:Play(ANIMATION_FADE, ANIMATION_WEIGHT, 1)
	end

	if params and params.Mini then
		task.wait(MINI_DELAY)
		if caster.Parent then
			showMini(caster, params.Colors)
		end
	end
end
