--!strict
--[[
	Sand fruit - Sandstorm, the drifting tornado.
	params: { Velocity: Vector3 (studs per second), Duration: number, Power: number
	          (defense affinity * charge 0-1), RightHand: boolean, Colors: string,
	          Caster: Model }
	Template: ReplicatedStorage.Assets.Models.Fruits.Sand.Power3.Sandstorm (a part whose
	Attachment holds the "Particles" emitter; the legacy script inside it spun that
	attachment, which is done here instead).

	`origin` is where the storm starts (the caster's root). It drifts along Velocity -
	the same path the server samples - upright, stops emitting after Duration seconds
	and is removed 5 seconds later. The caster's own client plays the release punch
	(PunchRight / PunchLeft at speed 3). As in the legacy game:
	  particle size     = clamp(4.175 * Power, 1, 15)
	  particle lifetime = clamp(3.75 * Power, 1, 12)
	  spin              = 200 degrees per second, speeding up to 420
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

local SIZE = 4.175
local SIZE_MIN = 1
local SIZE_MAX = 15
local LIFETIME = 3.75
local LIFETIME_MIN = 1
local LIFETIME_MAX = 12
local SPIN_START = 200
local SPIN_MAX = 420
-- The legacy script added 0.5 degrees per second on every Heartbeat (about 30 per second).
local SPIN_GAIN = 30
local FADE_SECONDS = 5
local PUNCH_FADE = 0.1
local PUNCH_SPEED = 3

return function(origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.Velocity) ~= "Vector3" or type(params.Duration) ~= "number" then
		return
	end
	local velocity: Vector3 = params.Velocity
	local duration: number = params.Duration
	local power: number = if type(params.Power) == "number" then params.Power else 1

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			local anims = AnimationConfig.FruitAnims
			Animations.Play(animator, if params.RightHand then anims.PunchRight else anims.PunchLeft, PUNCH_FADE, 1, PUNCH_SPEED)
		end
	end

	local template = EffectAssets.FindFruit("Sand", "Power3", "Sandstorm")
	if not template or not template:IsA("BasePart") then
		return
	end

	local storm = template:Clone()
	storm.Anchored = true
	storm.CanCollide = false
	storm.CanQuery = false
	storm.CanTouch = false

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	local emitters: { ParticleEmitter } = {}
	-- Child parts of the model (the legacy pull point) are anchored and carried along.
	local carried: { [BasePart]: CFrame } = {}
	for _, descendant in storm:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("Constraint") or descendant:IsA("JointInstance") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			carried[descendant] = storm.CFrame:ToObjectSpace(descendant.CFrame)
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("ParticleEmitter") then
			if descendant.Name == "Particles" then
				descendant.Size = NumberSequence.new(math.clamp(SIZE * power, SIZE_MIN, SIZE_MAX))
				descendant.Lifetime = NumberRange.new(math.clamp(LIFETIME * power, LIFETIME_MIN, LIFETIME_MAX))
			end
			if primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
			table.insert(emitters, descendant)
		end
	end

	local spinner = storm:FindFirstChild("Attachment")
	-- The legacy BodyGyro kept the storm upright.
	local rotation = CFrame.identity
	storm.CFrame = rotation + origin
	for part, offset in carried do
		part.CFrame = storm.CFrame * offset
	end
	storm.Parent = World.Effects()

	local started = os.clock()
	local spin = SPIN_START
	local fading = false
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local elapsed = os.clock() - started
		if elapsed >= duration + FADE_SECONDS then
			connection:Disconnect()
			storm:Destroy()
			return
		end

		if spinner and spinner:IsA("Attachment") then
			spinner.CFrame *= CFrame.Angles(0, math.rad(spin * deltaTime), 0)
			spin = math.min(spin + SPIN_GAIN * deltaTime, SPIN_MAX)
		end

		storm.CFrame = rotation + (origin + velocity * elapsed)
		for part, offset in carried do
			part.CFrame = storm.CFrame * offset
		end
		if elapsed >= duration and not fading then
			fading = true
			for _, emitter in emitters do
				emitter.Enabled = false
			end
		end
	end)
end
