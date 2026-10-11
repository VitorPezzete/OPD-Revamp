--!strict
--[[
	Snow fruit - Snow Angel.
	Status value: "<top speed in studs per second>|<fruit color string>".

	Everyone: two wings of snow on the back, flapping.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Snow.Power4.Wing1 / Wing2 (a part
	each, holding the visible wing "SnowRightWing" / "SnowLeftWing"). Each wing hangs
	from the torso by one weld whose C0 swings between 0 and 60 degrees, as the legacy
	server did every Heartbeat. Custom colors paint the wing parts with the first color.

	Owner only: the flight. Momentum builds towards the walk input (forward / backward
	input also follows the camera pitch) and bleeds off without input, exactly like the
	legacy "momentum * 0.96 + push" per frame but measured per second, so it feels the
	same at any frame rate. The body faces the momentum, tips forward until it lies flat
	at 50 studs per second (legacy Speed.Max) and banks into turns; hovering, it faces
	the camera.

	The flying pose is the shared FruitAnims.FlyingT clip, played with the defaults
	(fade 0.1, weight 1, speed 1): the legacy server asked the client for the animation
	named "FlyingT" of ReplicatedStorage.Animations (the Animation of the same name
	inside the Snow script, AnimationConfig.Fruits.Snow.FlyingT, was never played).

	The flight is carried by the legacy movers themselves (see buildCarrier): Snow flew
	on the Gas fruit's "Velociter", a BodyVelocity that is given the momentum and a
	BodyGyro that is given the facing.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_SPEED = 139
-- Fraction of the momentum kept after one 60 Hz frame in the legacy loop.
local MOMENTUM_KEPT_PER_FRAME = 0.96
local LEGACY_FRAME_RATE = 60
-- Below this the character is considered hovering.
local MIN_MOMENTUM = 1
-- Speed at which the body lies fully horizontal (legacy Speed.Max).
local FULL_TILT_SPEED = 50

-- Banking, per legacy frame: follow the turn rate while it is small, otherwise decay.
local BANK_KEEP = 0.77
local BANK_GAIN = 0.25
local BANK_DECAY = 0.9
local BANK_MIN_TURN = 0.0001
local BANK_MAX_TURN = 0.06
local BANK_ANGLE = -20

local WING_OFFSET = CFrame.new(0, 0, 0.45)
local FLAP_RATE = 3
local FLAP_ANGLE = math.rad(60)
-- Template name -> direction of its swing.
local WINGS: { [string]: number } = { Wing1 = 1, Wing2 = -1 }

type Wing = { Part: BasePart, Weld: JointInstance, Sign: number }

local function addWings(character: Model, colors: string): { Wing }
	local wings: { Wing } = {}
	local torso = character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return wings
	end

	local primary = FruitColor.Parse(colors)
	for templateName, sign in WINGS do
		local template = EffectAssets.FindFruit("Snow", "Power4", templateName)
		if not template or not template:IsA("BasePart") then
			continue
		end

		local wing = template:Clone()
		for _, descendant in wing:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = false
				descendant.CanCollide = false
				descendant.CanQuery = false
				descendant.CanTouch = false
				descendant.Massless = true
				if primary and (descendant.Name == "SnowRightWing" or descendant.Name == "SnowLeftWing") then
					descendant.Color = primary
				end
			end
		end
		wing.Anchored = false
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.Massless = true

		-- The template's torso joint is the "Weld" child (a ManualWeld) whose Part0 is empty:
		-- the legacy server filled it in at runtime. Welds holding the wing's own pieces are kept.
		local weld: JointInstance? = nil
		for _, child in wing:GetChildren() do
			if child:IsA("JointInstance") and child.Name == "Weld" and child.Part0 == nil then
				weld = child
				break
			end
		end
		if not weld then
			local created = Instance.new("Weld")
			created.Name = "TorsoWeld"
			created.Parent = wing
			weld = created
		end
		local joint = weld :: JointInstance
		joint.Part0 = torso
		joint.Part1 = wing
		joint.C0 = WING_OFFSET

		wing.Parent = character
		table.insert(wings, { Part = wing, Weld = joint, Sign = sign })
	end
	return wings
end

-- Only used when the carrier asset has lost its movers; the real values are the asset's.
local FALLBACK_TORQUE = Vector3.new(400000, 400000, 400000)
local FALLBACK_FORCE = Vector3.new(100000, 100000, 100000)

--[[
	The legacy flight: the Gas fruit's "Velociter" part welded to the root, holding the BodyGyro
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

	-- The legacy server made the character jump as the flight started.
	humanoid.Jump = true

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
	local wings = addWings(character, fields[2] or "")

	local elapsed = 0
	local flapConnection: RBXScriptConnection? = nil
	if #wings > 0 then
		flapConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			elapsed += deltaTime
			local angle = -math.abs(math.sin(elapsed * FLAP_RATE) * FLAP_ANGLE)
			for _, wing in wings do
				wing.Weld.C0 = WING_OFFSET * CFrame.Angles(0, angle * wing.Sign, 0)
			end
		end)
	end

	local stopFlight = if isLocal then startFlight(character, topSpeed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		if flapConnection then
			flapConnection:Disconnect()
		end
		for _, wing in wings do
			wing.Part:Destroy()
		end
	end
end
