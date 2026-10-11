--!strict
--[[
	Light fruit - Light Blast: the instant beam and the ball of light where it lands.
	origin: the hand the beam left from.
	params: { To: Vector3, Radius: number, Haki: boolean, Hand: "Right" | "Left",
	          Colors: string, Caster: Model }

	As in the legacy game both are plain neon parts (a 0.4 stud beam, a sphere of the
	blast diameter) shown for 0.4 s: yellow, the first fruit color, or dark with haki.
	They fade out over that time instead of vanishing at once.

	The caster's own client also plays the release animation of the hand that fired
	(replicated by the Animator).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 0)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local BEAM_THICKNESS = 0.4
local DURATION = 0.4
-- The legacy release clip was played 30 times faster than authored.
local RELEASE_SPEED = 30

local function neon(color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	return part
end

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.To
	local radius = params and params.Radius
	if not params or typeof(target) ~= "Vector3" or type(radius) ~= "number" then
		return
	end

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			local anims = AnimationConfig.FruitAnims
			local clip = if params.Hand == "Left" then anims.BeamReleaseLeft else anims.BeamReleaseRight
			Animations.Play(animator, clip, 0.1, 1, RELEASE_SPEED)
		end
	end

	local primary = EffectAssets.Colors(params.Colors, DEFAULT_COLOR, DEFAULT_COLOR)
	local color = if params.Haki then HAKI_COLOR else primary
	local fade = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	local length = (target - origin).Magnitude
	if length > 0.05 then
		local beam = neon(color)
		beam.Size = Vector3.new(BEAM_THICKNESS, BEAM_THICKNESS, length)
		beam.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -length / 2)
		beam.Parent = World.Effects()
		TweenService:Create(beam, fade, { Transparency = 1 }):Play()
		Debris:AddItem(beam, DURATION)
	end

	if radius > 0 then
		local ball = neon(color)
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		ball.CFrame = CFrame.new(target)
		ball.Parent = World.Effects()
		TweenService:Create(ball, fade, { Transparency = 1 }):Play()
		Debris:AddItem(ball, DURATION)
	end
end
