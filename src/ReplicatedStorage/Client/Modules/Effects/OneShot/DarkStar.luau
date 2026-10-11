--!strict
--[[
	Dark fruit - Dark Star in flight.
	params: { Direction: Vector3, Speed: number, Duration: number, Hand: "Right" | "Left",
	          Colors: string, Caster: Model }   (Hand: which release animation plays)
	Template: ReplicatedStorage.Assets.Models.Fruits.Dark.Power4.DarkStarBit (a part with
	an "Effect" emitter and an "OffPoint" child part).

	The copy is anchored and moved in a straight line from `origin` for `Duration`
	seconds, the path the server uses for the characters tied to the star.

	The caster's own client also plays the beam release animation (replicated by the
	Animator), when that asset loads in this copy of the game.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FADE_TIME = 0.5
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 30

local function playRelease(character: Model, hand: any)
	local anims = AnimationConfig.FruitAnims
	local animationId = if hand == "Left" then anims.BeamReleaseLeft else anims.BeamReleaseRight
	local animator = Animations.FindAnimator(character)
	if animator and Animations.IsAvailable(animationId) then
		Animations.Play(animator, animationId, RELEASE_FADE, 1, RELEASE_SPEED)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playRelease(caster, params.Hand)
	end

	local direction = params.Direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 200
	local duration: number = if type(params.Duration) == "number" and params.Duration > 0 then params.Duration else 1

	local template = EffectAssets.FindFruit("Dark", "Power4", "DarkStarBit")
	if not template or not template:IsA("BasePart") then
		return
	end

	local star = template:Clone()
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local emitters: { ParticleEmitter } = {}
	for _, descendant in star:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("LuaSourceContainer") then
			-- The inner part was only the server's rope anchor.
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			if primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
			table.insert(emitters, descendant)
		end
	end

	local unit = direction.Unit
	local rotation = CFrame.lookAt(origin, origin + unit).Rotation
	star.CFrame = rotation + origin
	star.Parent = World.Effects()

	TweenService:Create(star, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = rotation + (origin + unit * speed * duration),
	}):Play()

	task.delay(duration, function()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
		star.Transparency = 1
	end)
	Debris:AddItem(star, duration + FADE_TIME)
end
