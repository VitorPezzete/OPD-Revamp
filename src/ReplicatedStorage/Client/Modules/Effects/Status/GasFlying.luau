--!strict
--[[
	Gas fruit - Gas Form.
	Status value: "<top speed in studs per second>|<fruit color string>".

	Everyone: a gas shell welded over each of the six body parts.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Gas.Power1.GasPartHead / GasPartTorso /
	GasPartRArm / GasPartLArm / GasPartRLeg / GasPartLLeg (parts, each with a "GasBody"
	particle emitter). Custom colors paint both with the first color, as the legacy did.

	Owner only: the flight. Momentum builds towards the walk input (forward / backward
	input also follows the camera pitch) and bleeds off without input, exactly like the
	legacy "momentum * 0.96 + push" per frame but measured per second, so it feels the
	same at any frame rate. The body faces the momentum, tips forward until it lies flat
	at 40 studs per second and banks into turns; hovering, it faces the camera.

	The flying pose is the shared FruitAnims.FlyingT clip: the legacy server asked the
	client for the animation named "FlyingT" of ReplicatedStorage.Animations (the
	Animation of the same name inside the Gas script was never played).

	The flight is carried by the legacy movers themselves (see buildCarrier). Passing
	through the map is the server's doing (collision group), not this module's.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_SPEED = 111
-- Fraction of the momentum kept after one 60 Hz frame in the legacy loop.
local MOMENTUM_KEPT_PER_FRAME = 0.96
local LEGACY_FRAME_RATE = 60
-- Below this the character is considered hovering.
local MIN_MOMENTUM = 1
-- Speed at which the body lies fully horizontal (legacy Speed.Max).
local FULL_TILT_SPEED = 40

-- Banking, per legacy frame: follow the turn rate while it is small, otherwise decay.
local BANK_KEEP = 0.77
local BANK_GAIN = 0.25
local BANK_DECAY = 0.9
local BANK_MIN_TURN = 0.0001
local BANK_MAX_TURN = 0.06
local BANK_ANGLE = -20

local SHELLS = {
	{ Limb = "Head", Template = "GasPartHead" },
	{ Limb = "Torso", Template = "GasPartTorso" },
	{ Limb = "Right Arm", Template = "GasPartRArm" },
	{ Limb = "Left Arm", Template = "GasPartLArm" },
	{ Limb = "Right Leg", Template = "GasPartRLeg" },
	{ Limb = "Left Leg", Template = "GasPartLLeg" },
}

local function addShells(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local primary = FruitColor.Parse(colors)

	for _, shell in SHELLS do
		local limb = character:FindFirstChild(shell.Limb)
		local template = EffectAssets.FindFruit("Gas", "Power1", shell.Template)
		if limb and limb:IsA("BasePart") and template and template:IsA("BasePart") then
			local part = template:Clone()
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true

			if primary then
				part.Color = primary
				local body = part:FindFirstChild("GasBody")
				if body and body:IsA("ParticleEmitter") then
					body.Color = ColorSequence.new(primary)
				end
			end

			local weld = Instance.new("Weld")
			weld.Part0 = limb
			weld.Part1 = part
			weld.Parent = part

			part.Parent = character
			table.insert(created, part)
		end
	end
	return created
end

-- Only used when the carrier asset has lost its movers; the real values are the asset's.
local FALLBACK_TORQUE = Vector3.new(400000, 400000, 400000)
local FALLBACK_FORCE = Vector3.new(100000, 100000, 100000)

--[[
	The legacy flight: a "Velociter" part welded to the root, holding the BodyGyro
	("FlightGyro") and the BodyVelocity ("FlightVelocity") that carry the character. The
	very same part and movers are used, cloned from the asset, so their force, torque,
	stiffness and weight (hence how the flight accelerates, turns and sags) are the
	legacy ones. The legacy server made them; a player simulates its own character, so
	its client does.
]]
local function buildCarrier(root: BasePart): (BasePart, BodyGyro, BodyVelocity)
	local template = EffectAssets.FindFruit("Gas", "Power1", "Velociter")
	local carrier: BasePart
	if template and template:IsA("BasePart") then
		carrier = template:Clone()
		for _, descendant in carrier:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
	else
		carrier = Instance.new("Part")
		carrier.Size = Vector3.one
		carrier.Transparency = 1
		carrier.CanCollide = false
		carrier.Massless = true
	end
	carrier.Name = "Velociter"
	carrier.Anchored = false
	carrier.CFrame = root.CFrame

	local foundGyro = carrier:FindFirstChild("FlightGyro")
	local gyro: BodyGyro
	if foundGyro and foundGyro:IsA("BodyGyro") then
		gyro = foundGyro
	else
		gyro = Instance.new("BodyGyro")
		gyro.Name = "FlightGyro"
		gyro.MaxTorque = FALLBACK_TORQUE
		gyro.CFrame = root.CFrame.Rotation
		gyro.Parent = carrier
	end

	local foundMover = carrier:FindFirstChild("FlightVelocity")
	local mover: BodyVelocity
	if foundMover and foundMover:IsA("BodyVelocity") then
		mover = foundMover
	else
		mover = Instance.new("BodyVelocity")
		mover.Name = "FlightVelocity"
		mover.MaxForce = FALLBACK_FORCE
		mover.Velocity = Vector3.zero
		mover.Parent = carrier
	end

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = carrier
	weld.Parent = carrier
	carrier.Parent = root
	return carrier, gyro, mover
end

-- Returns the cleanup of the local flight, or nil when the character cannot fly.
local function startFlight(character: Model, topSpeed: number): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	local carrier, gyro, mover = buildCarrier(root)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local track: AnimationTrack? = nil
	if animator then
		local loaded = Animations.Get(animator, AnimationConfig.FruitAnims.FlyingT)
		loaded.Looped = true
		loaded:Play()
		track = loaded
	end

	local momentum = Vector3.zero
	local lastFlat = Vector3.zero
	local bank = 0

	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local camera = Workspace.CurrentCamera
		local frames = deltaTime * LEGACY_FRAME_RATE
		if not camera or frames <= 0 then
			return
		end
		local look = camera.CFrame.LookVector

		local push = Vector3.zero
		local move = humanoid.MoveDirection
		if move.Magnitude >= 0.01 then
			-- Input measured against the camera: 1 straight ahead, 0 sideways, -1 backwards.
			local flatLook = Vector3.new(look.X, 0, look.Z)
			local forward = 1
			if flatLook.Magnitude > 0.001 then
				local ahead = move.Unit:Dot(flatLook.Unit)
				forward = 1 - 2 * math.acos(math.clamp(ahead, -1, 1)) / math.pi
			end
			push = Vector3.new(move.X, look.Y * forward, move.Z) * topSpeed
		end

		local kept = MOMENTUM_KEPT_PER_FRAME ^ frames
		momentum = push + (momentum - push) * kept

		local flat = Vector3.new(momentum.X, 0, momentum.Z)
		local turn = 0
		if flat.Magnitude > 0.001 and lastFlat.Magnitude > 0.001 then
			turn = flat.Unit:Cross(lastFlat.Unit).Y / frames
		end
		lastFlat = flat

		local turnSize = math.abs(turn)
		if turnSize > BANK_MAX_TURN or turnSize < BANK_MIN_TURN then
			bank = if math.abs(bank) <= BANK_MIN_TURN then 0 else bank * BANK_DECAY ^ frames
		else
			local bankKept = BANK_KEEP ^ frames
			bank = bank * bankKept + turn * (1 - bankKept) * (BANK_GAIN / (1 - BANK_KEEP))
		end

		if momentum.Magnitude < MIN_MOMENTUM then
			-- Only snap to a stop while coasting, or a high frame rate could never start.
			if push == Vector3.zero then
				momentum = Vector3.zero
			end
			gyro.CFrame = camera.CFrame
		else
			local tilt = math.min(momentum.Magnitude / FULL_TILT_SPEED, 1)
			gyro.CFrame = CFrame.lookAt(Vector3.zero, momentum)
				* CFrame.Angles(0, 0, bank * BANK_ANGLE)
				* CFrame.Angles(-math.pi / 2 * tilt, 0, 0)
		end
		mover.Velocity = momentum
	end)

	return function()
		connection:Disconnect()
		carrier:Destroy()
		if track then
			track:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local topSpeed = tonumber(fields[1]) or DEFAULT_SPEED
	local shells = addShells(character, fields[2] or "")
	local stopFlight = if isLocal then startFlight(character, topSpeed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		for _, shell in shells do
			shell:Destroy()
		end
	end
end
