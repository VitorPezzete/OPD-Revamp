--!strict
--[[
	Sand fruit - Sand Flying.
	Status value: "<speed in studs per second>|<fruit color string>".

	Everyone: sand pouring out of both legs.
	Template: ReplicatedStorage.Assets.Models.Fruits.Sand.Power1.SandstormPart (ParticleEmitter).

	Owner only: the flight itself. The character faces where the camera looks, hovers
	with no input and moves along the walk input; forward / backward input also follows
	the camera pitch, so looking up while walking forward climbs.

	The legacy script did this with a BodyPosition chased 10000 studs ahead (the shared
	FlareJet resource) and played the Animation stored inside that resource at weight 3.
	The clip is read from Assets.Models.Fruits._Shared.FlareJet; the shared FlyingT clip
	stands in for it in a place without that asset.

	Two things that mover did besides reaching the status speed are kept:
	- Sand set its MaxForce to 40000 on each axis (Flare and Phoenix used 4000000), far
	  less than the pull of a goal 10000 studs away, so the force was saturated: the
	  flight takes a moment to pick up speed and glides to a stop instead of halting.
	  The same limit is on the LinearVelocity, per axis.
	- A BodyPosition does not cancel gravity: its damping (1250) only limits the fall, so
	  the character sank at weight / damping studs per second (2 to 3 for a character),
	  hovering or not.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_SPEED = 480
local FLIGHT_FORCE = 40000
local TURN_TORQUE = 4000000
-- Damping of the legacy BodyPosition (FlareJet).
local DAMPING = 1250
local ANIMATION_WEIGHT = 3
local ANIMATION_WEIGHT_FADE = 0.1
local LEGS = { "Right Leg", "Left Leg" }

local function addSand(character: Model, colors: string): { Instance }
	local created: { Instance } = {}

	local template = EffectAssets.FindFruit("Sand", "Power1", "SandstormPart")
	if template and template:IsA("ParticleEmitter") then
		local primary, secondary = FruitColor.Parse(colors)
		for _, legName in LEGS do
			local leg = character:FindFirstChild(legName)
			if leg and leg:IsA("BasePart") then
				local emitter = template:Clone()
				if primary and secondary then
					emitter.Color = FruitColor.ToSequence(primary, secondary)
				end
				emitter.Enabled = true
				emitter.Parent = leg
				table.insert(created, emitter)
			end
		end
	end
	return created
end

local function flightAnimation(): string
	local jet = EffectAssets.FindFruit("_Shared", "FlareJet")
	local animation = jet and jet:FindFirstChildOfClass("Animation")
	local id = if animation then string.match(animation.AnimationId, "%d+") else nil
	return if id then `rbxassetid://{id}` else AnimationConfig.FruitAnims.FlyingT
end

-- Returns the cleanup of the local flight, or nil when the character cannot fly.
local function startFlight(character: Model, speed: number): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	local attachment = Instance.new("Attachment")
	attachment.Name = "SandFlight"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	velocity.MaxAxesForce = Vector3.new(FLIGHT_FORCE, FLIGHT_FORCE, FLIGHT_FORCE)
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = attachment

	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = TURN_TORQUE
	align.Responsiveness = 50
	align.CFrame = root.CFrame.Rotation
	align.Parent = attachment

	local previousAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local track: AnimationTrack? = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local loaded = Animations.Get(animator, flightAnimation())
		loaded:Play()
		loaded:AdjustSpeed(1)
		loaded:AdjustWeight(ANIMATION_WEIGHT, ANIMATION_WEIGHT_FADE)
		track = loaded
	end

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local look = camera.CFrame.LookVector
		align.CFrame = CFrame.lookAt(Vector3.zero, look)

		local sink = Vector3.new(0, -root.AssemblyMass * Workspace.Gravity / DAMPING, 0)
		local move = humanoid.MoveDirection
		if move.Magnitude < 0.01 then
			velocity.VectorVelocity = sink
			return
		end

		-- Input measured against the camera: 1 straight ahead, 0 sideways, -1 backwards.
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local forward = 1
		if flatLook.Magnitude > 0.001 then
			local ahead = move.Unit:Dot(flatLook.Unit)
			forward = 1 - 2 * math.acos(math.clamp(ahead, -1, 1)) / math.pi
		end
		velocity.VectorVelocity = Vector3.new(move.X, look.Y * forward, move.Z) * speed + sink
	end)

	return function()
		connection:Disconnect()
		attachment:Destroy()
		humanoid.AutoRotate = previousAutoRotate
		if track then
			track:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local speed = tonumber(fields[1]) or DEFAULT_SPEED
	local created = addSand(character, fields[2] or "")
	local stopFlight = if isLocal then startFlight(character, speed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		for _, instance in created do
			instance:Destroy()
		end
	end
end
