--!strict
--[[
	Gravity fruit - Gravity Flying.
	Status value: "<top speed in studs per second>|<fruit color string>".

	Everyone: once or twice every half second a rock is torn from under the character
	and drifts up for 6 s. Templates: ReplicatedStorage.Assets.Models.Fruits.Gravity.
	Power1.Rocks.DebrisRock1..6 (parts with an Attachment holding a "GravityEffectSmall"
	emitter). A rock takes the material and color of the ground within 10 studs under
	the character, or the dark of armament haki. The aura on the body is a separate
	status (Effects.Status.GravityAura).

	Owner only: the flight. Momentum builds towards the walk input (forward / backward
	input also follows the camera pitch) and bleeds off without input, exactly like the
	legacy "momentum * 0.96 + push" per frame but measured per second, so it feels the
	same at any frame rate. The body faces the momentum, tips forward until it lies flat
	at 40 studs per second and banks into turns; hovering, it faces the camera.

	Banking, as the legacy loop did it per 60 Hz frame: with t the sine of the angle the
	horizontal heading turned in one frame, the bank follows 0.77 * bank + 0.25 * t while
	0.0001 <= |t| <= 0.06 and decays by 0.9 per frame otherwise; the body rolls by
	-20 * bank radians.

	The flight is carried by the legacy movers themselves (see buildCarrier). The legacy
	rocks were unanchored server parts pushed up by a BodyVelocity; they are anchored and
	tweened here.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

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
-- Speed at which the body lies fully horizontal.
local FULL_TILT_SPEED = 40
-- Banking (see the header): per 60 Hz frame.
local BANK_KEPT = 0.77
local BANK_GAIN = 0.25
local BANK_DECAY = 0.9
local BANK_MIN_TURN = 0.0001
local BANK_MAX_TURN = 0.06
local BANK_ROLL = -20

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local ROCK_INTERVAL = 0.5
local ROCK_KINDS = 6
local ROCK_SPREAD = 10
local ROCK_LIFETIME = 6
local ROCK_FADE = 1
-- The legacy rock stopped shedding particles a quarter of a second before it was removed.
local ROCK_EMITTER_TIME = 5.75
-- The legacy rocks rose at 1 stud per second.
local ROCK_RISE = Vector3.new(0, ROCK_LIFETIME, 0)
local GROUND_REACH = 10

local random = Random.new()

local function spawnRock(character: Model, root: BasePart, folder: Instance, primary: Color3?)
	local template = folder:FindFirstChild(`DebrisRock{random:NextInteger(1, ROCK_KINDS)}`)
	if not template or not template:IsA("BasePart") then
		return
	end

	local rock = template:Clone()
	rock.Anchored = true
	rock.CanCollide = false
	rock.CanQuery = false
	rock.CanTouch = false

	if character:GetAttribute(HAKI_ATTRIBUTE) then
		rock.Color = HAKI_COLOR
	else
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local ground = Workspace:Raycast(root.Position, Vector3.new(0, -GROUND_REACH, 0), params)
		-- Terrain has no part color, and some of its materials cannot be put on a part.
		if ground and ground.Instance:IsA("BasePart") and not ground.Instance:IsA("Terrain") then
			rock.Material = ground.Instance.Material
			rock.Color = ground.Instance.Color
		end
	end

	local emitters: { ParticleEmitter } = {}
	for _, descendant in rock:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant:IsA("BodyMover") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			if primary then
				descendant.Color = ColorSequence.new(primary)
			end
			table.insert(emitters, descendant)
		end
	end

	rock.Position = root.Position
		+ Vector3.new(
			random:NextInteger(-ROCK_SPREAD, ROCK_SPREAD),
			random:NextInteger(-7, -5),
			random:NextInteger(-ROCK_SPREAD, ROCK_SPREAD)
		)
	rock.Parent = World.Effects()

	TweenService:Create(rock, TweenInfo.new(ROCK_LIFETIME, Enum.EasingStyle.Linear), {
		Position = rock.Position + ROCK_RISE,
	}):Play()
	task.delay(ROCK_LIFETIME - ROCK_FADE, function()
		TweenService:Create(rock, TweenInfo.new(ROCK_FADE), { Transparency = 1 }):Play()
	end)
	task.delay(ROCK_EMITTER_TIME, function()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
	end)
	Debris:AddItem(rock, ROCK_LIFETIME)
end

-- Returns the cleanup of the rock shower, or nil when there is nothing to draw.
local function startRocks(character: Model, colors: string): (() -> ())?
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	local foundFolder = EffectAssets.FindFruit("Gravity", "Power1", "Rocks")
	if not foundRoot or not foundRoot:IsA("BasePart") or not foundFolder then
		return nil
	end
	local root: BasePart, folder: Instance = foundRoot, foundFolder

	local primary = FruitColor.Parse(colors)
	local active = true
	task.spawn(function()
		while true do
			task.wait(ROCK_INTERVAL)
			if not active or not root.Parent then
				return
			end
			for _ = 1, random:NextInteger(1, 2) do
				spawnRock(character, root, folder, primary)
			end
		end
	end)

	return function()
		active = false
	end
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
	local template = EffectAssets.FindFruit("Gravity", "Power1", "Velociter")
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
	-- The shared flying clip: the one the legacy game played (the fruit's own FlyingT
	-- animation was never used, and this place has no permission to load it).
	local animationId = AnimationConfig.FruitAnims.FlyingT
	local track: AnimationTrack? = nil
	if animator and type(animationId) == "string" then
		local loaded = Animations.Get(animator, animationId)
		loaded.Looped = true
		loaded:Play()
		track = loaded
	end

	local momentum = Vector3.zero
	local bank = 0

	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local camera = Workspace.CurrentCamera
		if not camera then
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

		local frames = deltaTime * LEGACY_FRAME_RATE
		local previous = momentum
		momentum = push + (momentum - push) * MOMENTUM_KEPT_PER_FRAME ^ frames

		local turn = 0
		local heading = Vector3.new(momentum.X, 0, momentum.Z)
		local previousHeading = Vector3.new(previous.X, 0, previous.Z)
		if frames > 0 and heading.Magnitude > 1e-4 and previousHeading.Magnitude > 1e-4 then
			turn = heading.Unit:Cross(previousHeading.Unit).Y / frames
		end
		if math.abs(turn) > BANK_MAX_TURN or math.abs(turn) < BANK_MIN_TURN then
			bank = if math.abs(bank) <= BANK_MIN_TURN then 0 else bank * BANK_DECAY ^ frames
		else
			local settled = turn * BANK_GAIN / (1 - BANK_KEPT)
			bank = settled + (bank - settled) * BANK_KEPT ^ frames
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
				* CFrame.Angles(0, 0, bank * BANK_ROLL)
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
	local colors = fields[2] or ""

	local stopRocks = startRocks(character, colors)
	local stopFlight = if isLocal then startFlight(character, topSpeed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		if stopRocks then
			stopRocks()
		end
	end
end
