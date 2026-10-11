--!strict
--[[
	Hot fruit - Nose Jet.
	Status value: "<top speed in studs per second>|<fruit color string>".

	Everyone: two jets of heat welded to the head, angled out from the nose.
	Template: ReplicatedStorage.Assets.Models.Fruits.Hot.Power1.WeldablePart (a part
	with particle emitters). Custom colors: only the first jet's part takes the first
	color, which is all the legacy script managed to paint (its next line, meant for the
	particles of the second jet, threw).

	Owner only: the flight. Momentum builds towards the walk input (forward / backward
	input also follows the camera pitch) and bleeds off without input, exactly like the
	legacy "momentum * 0.96 + push" per frame but measured per second, so it feels the
	same at any frame rate. The body faces the momentum and tips forward until it lies
	flat at 50 studs per second; hovering, it faces the camera.

	Movers: the legacy "Velociter" part (Assets.Models.Fruits.Hot.Power1.Velociter) with
	its FlightVelocity / FlightGyro, welded to the root by the owner's client instead of
	the server, so the flight has the legacy force and stiffness. The body also banks
	into turns, as it did.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local DEFAULT_SPEED = 139
local FLIGHT_FORCE = 4000000
-- Fraction of the momentum kept after one 60 Hz frame in the legacy loop.
local MOMENTUM_KEPT_PER_FRAME = 0.96
local LEGACY_FRAME_RATE = 60
-- Below this the character is considered hovering.
local MIN_MOMENTUM = 1
-- Speed at which the body lies fully horizontal.
local FULL_TILT_SPEED = 50
-- Banking (per rendered frame, as in the legacy loop): turns sharper than BANK_MAX_TURN
-- or absent let the roll fade by BANK_FADE; otherwise it follows the turn.
local BANK_MAX_TURN = 0.06
local BANK_EPSILON = 0.0001
local BANK_FADE = 0.9
local BANK_KEEP = 0.77
local BANK_GAIN = 0.25
local BANK_ROLL = -20

local JET_OFFSETS = {
	CFrame.new(0, 0.05, -0.4) * CFrame.Angles(math.rad(15), 0, math.rad(10)),
	CFrame.new(0, 0.05, -0.4) * CFrame.Angles(math.rad(15), 0, math.rad(-10)),
}

local function findAsset(...: string): Instance?
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { ... } do
		if not current then
			return nil
		end
		current = current:FindFirstChild(name)
	end
	return current
end

local function parseValue(value: any): (number, string)
	if type(value) ~= "string" then
		return DEFAULT_SPEED, ""
	end
	local speed, colors = string.match(value, "^(%d+)|(.*)$")
	return tonumber(speed) or DEFAULT_SPEED, (colors or "") :: string
end

local function addJets(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local head = character:FindFirstChild("Head")
	local template = findAsset("Models", "Fruits", "Hot", "Power1", "WeldablePart")
	if not head or not head:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return created
	end

	local primary = FruitColor.Parse(colors)
	for index, offset in JET_OFFSETS do
		local jet = template:Clone()
		jet.Anchored = false
		jet.CanCollide = false
		jet.CanQuery = false
		jet.CanTouch = false
		jet.Massless = true

		if primary and index == 1 then
			jet.Color = primary
		end

		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = jet
		weld.C0 = offset
		weld.Parent = jet

		jet.Parent = head
		table.insert(created, jet)
	end
	return created
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

	local created: { Instance } = {}
	local setVelocity: (Vector3) -> ()
	local setOrientation: (CFrame) -> ()
	local previousAutoRotate: boolean? = nil

	-- The legacy movers themselves: the "Velociter" part welded to the root, with its
	-- authored FlightVelocity (BodyVelocity) and FlightGyro (BodyGyro), so the force,
	-- stiffness and damping of the flight are the legacy ones.
	local template = findAsset("Models", "Fruits", "Hot", "Power1", "Velociter")
	local velociter = if template and template:IsA("BasePart") then template:Clone() else nil
	local bodyVelocity = velociter and velociter:FindFirstChild("FlightVelocity")
	local bodyGyro = velociter and velociter:FindFirstChild("FlightGyro")
	if velociter and bodyVelocity and bodyVelocity:IsA("BodyVelocity") and bodyGyro and bodyGyro:IsA("BodyGyro") then
		for _, descendant in velociter:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		velociter.Anchored = false
		velociter.CFrame = root.CFrame

		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = velociter
		weld.Parent = velociter
		velociter.Parent = root
		table.insert(created, velociter)

		local velocityMover: BodyVelocity, gyroMover: BodyGyro = bodyVelocity, bodyGyro
		setVelocity = function(value: Vector3)
			velocityMover.Velocity = value
		end
		setOrientation = function(value: CFrame)
			gyroMover.CFrame = value
		end
	else
		-- Asset missing: constraints standing in for the two movers.
		if velociter then
			velociter:Destroy()
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "HotFlight"
		attachment.Parent = root
		table.insert(created, attachment)

		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		velocity.MaxForce = FLIGHT_FORCE
		velocity.VectorVelocity = Vector3.zero
		velocity.Parent = attachment

		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.MaxTorque = FLIGHT_FORCE
		align.Responsiveness = 50
		align.CFrame = root.CFrame.Rotation
		align.Parent = attachment

		previousAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false

		setVelocity = function(value: Vector3)
			velocity.VectorVelocity = value
		end
		setOrientation = function(value: CFrame)
			align.CFrame = value.Rotation
		end
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	-- The shared flying clip (ReplicatedStorage.Animations "FlyingT"): the legacy server
	-- asked the character's animation script for "FlyingT", which only knew the shared
	-- animations. The FlyingT animation stored inside the fruit's script was never played.
	local animationId = AnimationConfig.FruitAnims.FlyingT
	local track: AnimationTrack? = nil
	if animator and type(animationId) == "string" then
		local loaded = Animations.Get(animator, animationId)
		loaded:Play()
		track = loaded
	end

	local momentum = Vector3.zero
	local lastMomentum = Vector3.zero
	local lastTilt = 0

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

		local kept = MOMENTUM_KEPT_PER_FRAME ^ (deltaTime * LEGACY_FRAME_RATE)
		momentum = push + (momentum - push) * kept

		-- Banking: the body rolls into a turn. The turn is read from how far the flat
		-- heading moved since the last frame; sharp turns (and no turn) let the roll fade.
		local flat = Vector3.new(momentum.X, 0, momentum.Z)
		local lastFlat = Vector3.new(lastMomentum.X, 0, lastMomentum.Z)
		local turn = 0
		if flat.Magnitude > 0 and lastFlat.Magnitude > 0 then
			turn = flat.Unit:Cross(lastFlat.Unit).Y
		end
		local sharpness = math.abs(turn)
		if sharpness > BANK_MAX_TURN or sharpness < BANK_EPSILON then
			lastTilt = if math.abs(lastTilt) > BANK_EPSILON then lastTilt * BANK_FADE else 0
		else
			lastTilt = lastTilt * BANK_KEEP + turn * BANK_GAIN
		end

		local speed = math.min(momentum.Magnitude, FULL_TILT_SPEED)
		if speed < MIN_MOMENTUM then
			-- Only snap to a stop while coasting, or a high frame rate could never start.
			if push == Vector3.zero then
				momentum = Vector3.zero
			end
			setOrientation(camera.CFrame)
		else
			setOrientation(
				CFrame.lookAt(Vector3.zero, momentum)
					* CFrame.Angles(0, 0, lastTilt * BANK_ROLL)
					* CFrame.Angles(-math.pi / 2 * speed / FULL_TILT_SPEED, 0, 0)
			)
		end
		setVelocity(momentum)
		lastMomentum = momentum
	end)

	return function()
		connection:Disconnect()
		for _, instance in created do
			instance:Destroy()
		end
		if previousAutoRotate ~= nil then
			humanoid.AutoRotate = previousAutoRotate
		end
		if track then
			track:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local topSpeed, colors = parseValue(value)
	local jets = addJets(character, colors)
	local stopFlight = if isLocal then startFlight(character, topSpeed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		for _, jet in jets do
			jet:Destroy()
		end
	end
end
