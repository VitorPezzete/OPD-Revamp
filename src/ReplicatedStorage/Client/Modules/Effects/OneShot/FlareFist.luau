--!strict
--[[
	Flare fruit - Fire Fist, the flying fist.
	params: { Direction: Vector3, Speed: number, Range: number, Percent: number (charge
	          0-1), Multiplier: number (affinity * level scale), Haki: boolean,
	          Hand: "Right" | "Left", Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power2["Fire Fist"] (an orange
	ball with a "Fire" emitter).

	Size, as in the legacy game: max(template size * Percent, 4) * Multiplier per axis;
	the particles follow the same rule from their first size keypoint.
	Colors, as in the legacy game: the fruit colors go on the particles only (the ball
	keeps its orange); armament haki darkens both.
	The copy is anchored and tweened along the path the server is casting, stopping at
	the first wall. The thrower's own client also plays the punch animation (replicated
	by the Animator).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local World = require(ReplicatedStorage.Shared.Util.World)

local MIN_SIZE = 4
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_PARTICLES = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local FADE_TIME = 0.6
-- Longest single cast; further than this is out of sight anyway.
local PUNCH_FADE = 0.1
local PUNCH_SPEED = 3

local function playPunch(character: Model, left: boolean)
	local animator = Animations.FindAnimator(character)
	if not animator then
		return
	end

	local anims = AnimationConfig.FruitAnims
	Animations.Play(animator, if left then anims.PunchLeft else anims.PunchRight, PUNCH_FADE, 1, PUNCH_SPEED)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3 then
		return
	end

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playPunch(caster, params.Hand == "Left")
	end
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 250
	local range: number = if type(params.Range) == "number" then params.Range else 1500
	local percent: number = if type(params.Percent) == "number" then params.Percent else 1
	local multiplier: number = if type(params.Multiplier) == "number" then params.Multiplier else 1

	local template = EffectAssets.FindFruit("Flare", "Power2", "Fire Fist")
	if not template or not template:IsA("BasePart") then
		return
	end

	local fist = template:Clone()
	fist.Anchored = true
	fist.CanCollide = false
	fist.CanQuery = false
	fist.CanTouch = false

	local base = template.Size
	fist.Size = Vector3.new(
		math.max(base.X * percent, MIN_SIZE),
		math.max(base.Y * percent, MIN_SIZE),
		math.max(base.Z * percent, MIN_SIZE)
	) * multiplier

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if params.Haki then
		fist.Color = HAKI_COLOR
	end

	local emitters: { ParticleEmitter } = {}
	for _, descendant in fist:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			local keypoint = descendant.Size.Keypoints[1]
			local baseSize = if keypoint then keypoint.Value else 1
			descendant.Size = NumberSequence.new(math.max(baseSize * percent, MIN_SIZE) * multiplier)
			if params.Haki then
				descendant.Color = HAKI_PARTICLES
			elseif primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
			table.insert(emitters, descendant)
		end
	end

	-- Nothing stops the fist, neither characters nor the map (as the server's cast and
	-- the legacy part): it flies its whole range.
	local unit = direction.Unit
	local distance = range
	local duration = math.max(distance / speed, 0.03)

	local rotation = CFrame.lookAt(origin, origin + unit).Rotation
	fist.CFrame = rotation + origin
	fist.Parent = World.Effects()

	TweenService:Create(fist, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = rotation + (origin + unit * distance),
	}):Play()

	task.delay(duration, function()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
		fist.Transparency = 1
	end)
	Debris:AddItem(fist, duration + FADE_TIME)
end
