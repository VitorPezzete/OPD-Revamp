--!strict
--[[
	Flare fruit - Flame Pillar, the travelling column of fire.
	params: { Direction: Vector3, Distance: number, Speed: number, Size: Vector3 (full
	          size), GrowTime: number, Lifetime: number, Rotation: CFrame (the caster's
	          facing), ParticleScale: number (defense affinity), Haki: boolean,
	          Hand: "Right" | "Left", Colors: string, Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power5.FlarePillar (an
	invisible part with an "Effect" emitter locked to it).

	A local anchored copy leaves `origin`, moves `Distance` studs along `Direction` at
	`Speed`, grows linearly to `Size` over `GrowTime` and is removed after `Lifetime`: the
	same motion the server uses for its hit box. As in the legacy game it keeps the
	caster's facing while it travels and spins two turns a second once it has arrived,
	and its particles are `ParticleScale` times their authored size.

	Both fruit colors on the particles; dark with armament haki.
	The caster's own client also plays the punch animation (replicated by the Animator).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_PARTICLES = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local MIN_SIZE = 0.1
-- Degrees per second, once the pillar stands still.
local SPIN = 720
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

local function scaled(sequence: NumberSequence, scale: number): NumberSequence
	local keypoints: { NumberSequenceKeypoint } = {}
	for _, keypoint in sequence.Keypoints do
		table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale))
	end
	return NumberSequence.new(keypoints)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local direction = params.Direction
	local fullSize = params.Size
	if typeof(direction) ~= "Vector3" or typeof(fullSize) ~= "Vector3" then
		return
	end

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playPunch(caster, params.Hand == "Left")
	end

	local distance: number = if type(params.Distance) == "number" then params.Distance else 0
	local speed: number = if type(params.Speed) == "number" and params.Speed > 0 then params.Speed else 50
	local growTime: number = if type(params.GrowTime) == "number" and params.GrowTime > 0 then params.GrowTime else 5
	local lifetime: number = if type(params.Lifetime) == "number" then params.Lifetime else 8
	local facing: CFrame = if typeof(params.Rotation) == "CFrame" then params.Rotation.Rotation else CFrame.identity
	local particleScale: number = if type(params.ParticleScale) == "number" and params.ParticleScale > 0
		then params.ParticleScale
		else 1

	local template = EffectAssets.FindFruit("Flare", "Power5", "FlarePillar")
	if not template or not template:IsA("BasePart") then
		return
	end

	local pillar = template:Clone()
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.Size = Vector3.one * MIN_SIZE

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	for _, descendant in pillar:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Size = scaled(descendant.Size, particleScale)
			if params.Haki then
				descendant.Color = HAKI_PARTICLES
			elseif primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
		end
	end

	pillar.CFrame = facing + origin
	pillar.Parent = World.Effects()

	local travelTime = distance / speed
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - started
		if elapsed >= lifetime then
			connection:Disconnect()
			pillar:Destroy()
			return
		end

		local size = fullSize * math.min(elapsed / growTime, 1)
		pillar.Size = Vector3.new(math.max(size.X, MIN_SIZE), math.max(size.Y, MIN_SIZE), math.max(size.Z, MIN_SIZE))
		local position = origin + direction * math.min(elapsed * speed, distance)
		local spin = math.rad(SPIN * math.max(elapsed - travelTime, 0))
		pillar.CFrame = (facing + position) * CFrame.Angles(0, spin, 0)
	end)
end
