--!strict
--[[
	Vampire fruit - Bat Swarm in flight. Cosmetic: the server advances its own point at
	the same speed towards the same target and decides when the swarm latches on.

	origin: where the swarm leaves from (the hand that threw it).
	params: one of
	  { Target: Model, Speed, Duration, LatchDistance }  - chases the target's root and
	    disappears half a second after getting within LatchDistance (the bites are the
	    VampireBatSwarmHit effect);
	  { Direction: Vector3, Speed, Duration }            - flies straight, harmless.
	Plus Hand ("Right" | "Left"), WithBat, Colors and Caster.

	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power5.VampireBatSwarm (a
	part with an "Effect" emitter). Custom colors use the first color.

	WithBat: the raised bat sent along in attack mode flies in the middle of the swarm,
	flapping, as the legacy one did welded to it. It is a copy of
	Assets.Models.Fruits.Vampire.Power4.Bat, painted like the orbiting bats.

	The thrower's own client also plays the punch of the throwing hand (replicated by
	the Animator).
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local LATCH_LINGER = 0.5
local PUNCH_FADE = 0.1
local PUNCH_SPEED = 3
-- The legacy bat AI: its clock ran four times real time, the wings beat on sin(6 t).
local FLAP_RATE = 4
local FLAP_FREQUENCY = 6
local FLAP_ANGLE = math.rad(40)
local BAT_PAINTED: { [string]: boolean } = { Torso = true, Head = true, LeftWing = true, RightWing = true }

type Bat = { Model: Model, Torso: BasePart, LeftJoint: JointInstance?, RightJoint: JointInstance? }

local function playPunch(character: Model, left: boolean)
	local animator = Animations.FindAnimator(character)
	if not animator then
		return
	end
	local anims = AnimationConfig.FruitAnims
	Animations.Play(animator, if left then anims.PunchLeft else anims.PunchRight, PUNCH_FADE, 1, PUNCH_SPEED)
end

local function findJoint(model: Model, partName: string): JointInstance?
	local part = model:FindFirstChild(partName)
	local joint = part and part:FindFirstChild(partName)
	return if joint and joint:IsA("JointInstance") then joint else nil
end

local function makeBat(primary: Color3?): Bat?
	local template = EffectAssets.FindFruit("Vampire", "Power4", "Bat")
	if not template or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
	local torso = model:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant == torso
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			if primary and BAT_PAINTED[descendant.Name] then
				descendant.Color = primary
			end
		end
	end
	return {
		Model = model,
		Torso = torso,
		LeftJoint = findJoint(model, "LeftWing"),
		RightJoint = findJoint(model, "RightWing"),
	}
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local speed = params.Speed
	local duration = params.Duration
	if type(speed) ~= "number" or type(duration) ~= "number" or speed <= 0 or duration <= 0 then
		return
	end

	local localPlayer = Players.LocalPlayer
	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and localPlayer and caster == localPlayer.Character then
		playPunch(caster, params.Hand == "Left")
	end

	local targetRoot: BasePart? = nil
	if typeof(params.Target) == "Instance" then
		local found = params.Target:FindFirstChild("HumanoidRootPart")
		if found and found:IsA("BasePart") then
			targetRoot = found
		end
	end
	local direction = params.Direction
	if not targetRoot and (typeof(direction) ~= "Vector3" or direction.Magnitude < 1e-3) then
		return
	end
	local latchDistance: number = if type(params.LatchDistance) == "number" then params.LatchDistance else 10

	local template = EffectAssets.FindFruit("Vampire", "Power5", "VampireBatSwarm")
	if not template or not template:IsA("BasePart") then
		return
	end

	local swarm = template:Clone()
	swarm.Anchored = true
	swarm.CanCollide = false
	swarm.CanQuery = false
	swarm.CanTouch = false

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if primary then
		for _, descendant in swarm:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Color = ColorSequence.new(primary)
			end
		end
	end

	local bat: Bat? = if params.WithBat then makeBat(primary) else nil

	local position = origin
	local heading: Vector3 = if targetRoot then targetRoot.Position - origin else direction
	local function place()
		local cframe = if heading.Magnitude > 1e-3 then CFrame.lookAt(position, position + heading) else CFrame.new(position)
		swarm.CFrame = cframe
		if bat then
			bat.Torso.CFrame = cframe
		end
	end
	place()
	swarm.Parent = World.Effects()
	Debris:AddItem(swarm, duration)
	if bat then
		-- Inside the swarm part, so it goes whenever the swarm does.
		bat.Model.Parent = swarm
	end

	local clock = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		if not swarm.Parent then
			connection:Disconnect()
			return
		end

		if bat then
			clock += deltaTime * FLAP_RATE
			local wingAngle = math.sin(clock * FLAP_FREQUENCY) * FLAP_ANGLE
			if bat.LeftJoint then
				bat.LeftJoint.C0 = CFrame.new(-0.134, 0.134, 0) * CFrame.Angles(0, wingAngle, 0)
			end
			if bat.RightJoint then
				bat.RightJoint.C0 = CFrame.new(0.134, 0.134, 0) * CFrame.Angles(0, -wingAngle, 0)
			end
		end

		if targetRoot then
			if not targetRoot.Parent then
				connection:Disconnect()
				swarm:Destroy()
				return
			end
			local offset = targetRoot.Position - position
			if offset.Magnitude < latchDistance then
				connection:Disconnect()
				Debris:AddItem(swarm, LATCH_LINGER)
				return
			end
			heading = offset
			position += offset.Unit * math.min(speed * deltaTime, offset.Magnitude)
		else
			position += (direction :: Vector3).Unit * speed * deltaTime
		end
		place()
	end)
end
