--!strict
--[[
	Love fruit - Pistol Kiss: one shot. A thin beam from the hand to the hit point and a
	heart that pops there (grows in 0.1 s, shrinks from 0.2 s, gone at 0.5 s). The beam
	is the plain grey neon part of the legacy game, or the fruit's second color; the
	heart keeps its authored color, or takes the first. The caster's own client also
	plays the recoil of the shot (the legacy "beam release" clip, very fast).

	params: { Target: Vector3, Scale: number (sniper affinity), Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Love.Power3.LoveHeart (a MeshPart);
	the beam is built here and is still drawn when the template is missing.
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

local LIFETIME = 0.5
local BEAM_THICKNESS = 0.4
local BEAM_TRANSPARENCY = 0.8
-- Color of a part nobody painted ("Medium stone grey").
local BEAM_COLOR = Color3.fromRGB(163, 162, 165)
local RECOIL_FADE = 0.1
local RECOIL_SPEED = 30
local HEART_SIZE = Vector3.new(10, 10, 6)
local HEART_END_SIZE = Vector3.new(0.1, 0.1, 0.5)
local GROW_TIME = 0.1
local SHRINK_DELAY = 0.2
local SHRINK_TIME = 0.3

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	if not params or typeof(target) ~= "Vector3" then
		return
	end

	local distance = (target - origin).Magnitude
	if distance < 0.05 then
		return
	end
	local scale: number = if type(params.Scale) == "number" then params.Scale else 1
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			Animations.Play(animator, AnimationConfig.FruitAnims.BeamReleaseRight, RECOIL_FADE, 1, RECOIL_SPEED)
		end
	end

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = secondary or BEAM_COLOR
	beam.Transparency = BEAM_TRANSPARENCY
	beam.Size = Vector3.new(BEAM_THICKNESS, BEAM_THICKNESS, distance)
	beam.CFrame = CFrame.lookAt(origin, target) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = World.Effects()
	Debris:AddItem(beam, LIFETIME)

	local template = EffectAssets.FindFruit("Love", "Power3", "LoveHeart")
	if not template or not template:IsA("BasePart") then
		return
	end

	local heart = template:Clone()
	heart.Anchored = true
	heart.CanCollide = false
	heart.CanQuery = false
	heart.CanTouch = false
	heart.CFrame = CFrame.lookAt(target, origin)
	if primary then
		heart.Color = primary
	end
	heart.Parent = World.Effects()
	Debris:AddItem(heart, LIFETIME)

	TweenService:Create(heart, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear), { Size = HEART_SIZE * scale }):Play()
	task.delay(SHRINK_DELAY, function()
		if heart.Parent then
			TweenService:Create(heart, TweenInfo.new(SHRINK_TIME, Enum.EasingStyle.Linear), { Size = HEART_END_SIZE }):Play()
		end
	end)
end
