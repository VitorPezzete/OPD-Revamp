--!strict
--[[
	Float fruit flight (Levitate). The status value is the top speed, decided by the server.

	Every client: the carrier part the legacy game welded to the root, borrowed from the
	Gas fruit (ReplicatedStorage.Assets.Models.Fruits.Gas.Power1.Velociter).

	Owner: that carrier keeps its two movers, the BodyGyro "FlightGyro" and the
	BodyVelocity "FlightVelocity", and they carry the character exactly as in the legacy
	game: same force, torque, stiffness and weight. The legacy Float server also put a
	second, untouched BodyGyro and BodyVelocity in the carrier (it meant to create the
	movers and the asset already had them): a gyro holding the body upright against the
	lean and a mover pulling towards (0, 2, 0) with 4000 of force. Both act on the body
	for the whole flight and are part of how Levitate handles, so both are recreated.

	Owner only: the flight itself and the flying animation.
	- Wanted velocity: move direction horizontally, plus the camera's vertical look scaled
	  by how much the character is moving forward (1) or backward (-1) relative to the
	  camera, all times the top speed.
	- The actual velocity eases toward it, keeping 96% of itself per 1/60 s.
	- The body leans forward with speed (flat at 30 studs/s and above) and banks in turns.

	The legacy code did the easing and the banking once per rendered frame, so both
	changed with the frame rate. Here they are scaled by the frame time.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local CARRIER_PATH = { "Models", "Fruits", "Gas", "Power1", "Velociter" }
local REFERENCE_RATE = 60
-- Fraction of the velocity kept per reference frame.
local KEEP = 0.96
-- Used when the status carries no number: the level 0 top speed (25 * 30 / 9).
local DEFAULT_SPEED = 250 / 3
-- Speed at which the body is fully horizontal.
local LEAN_SPEED = 30
local MAX_LEAN = math.pi / 2
local LIFT = Vector3.new(0, 2, 0)
-- Only used when the carrier asset has lost its movers; the real values are the asset's.
local FALLBACK_TORQUE = Vector3.new(400000, 400000, 400000)
local FALLBACK_FORCE = Vector3.new(100000, 100000, 100000)

-- Banking, per reference frame: follow the turn rate while it is small, otherwise decay.
local BANK_KEEP = 0.77
local BANK_GAIN = 0.25
local BANK_DECAY = 0.9
local BANK_MIN_TURN = 0.0001
local BANK_MAX_TURN = 0.06
local BANK_ANGLE = -20

local function noop() end

-- `flown`: the owner's carrier, which keeps the movers and the weight of the asset.
local function buildCarrier(root: BasePart, flown: boolean): BasePart?
	local node: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, childName in CARRIER_PATH do
		node = node and node:FindFirstChild(childName)
	end

	local carrier: BasePart
	if node and node:IsA("BasePart") then
		carrier = node:Clone()
	elseif flown then
		carrier = Instance.new("Part")
		carrier.Size = Vector3.one
		carrier.Transparency = 1
		carrier.CanCollide = false
		carrier.Massless = true
	else
		return nil
	end
	carrier.Name = "FloatVelociter"
	for _, descendant in carrier:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif not flown and (descendant:IsA("BodyMover") or descendant:IsA("Constraint") or descendant:IsA("JointInstance")) then
			-- Other clients only want the look.
			descendant:Destroy()
		end
	end
	carrier.Anchored = false
	if not flown then
		carrier.CanCollide = false
		carrier.CanQuery = false
		carrier.CanTouch = false
		carrier.Massless = true
	end
	carrier.CFrame = root.CFrame

	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = carrier
	weld.Parent = carrier
	carrier.Parent = root
	return carrier
end

-- The two movers of the flight inside the owner's carrier, and the two the legacy
-- server added on top (see the header), left at their defaults.
local function getMovers(carrier: BasePart, root: BasePart): (BodyGyro, BodyVelocity)
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

	local idleGyro = Instance.new("BodyGyro")
	idleGyro.Name = "FlightGyro"
	idleGyro.Parent = carrier
	local idleMover = Instance.new("BodyVelocity")
	idleMover.Name = "FlightVelocity"
	idleMover.Parent = carrier

	return gyro, mover
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	local humanoid: Humanoid = foundHumanoid
	local root: BasePart = foundRoot

	local carrier = buildCarrier(root, isLocal)
	if not isLocal or not carrier then
		return function()
			if carrier then
				carrier:Destroy()
			end
		end
	end

	local topSpeed: number = if type(value) == "number" then value else DEFAULT_SPEED

	-- Off the ground first, so the humanoid stops standing on it.
	character:PivotTo(character:GetPivot() + LIFT)

	local gyro, mover = getMovers(carrier, root)

	local track: AnimationTrack? = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local loaded = Animations.Get(animator, AnimationConfig.FruitAnims.FlyingT)
		-- FruitAnims.FlyingT is shared with FlareFlying, which loops it.
		loaded.Looped = true
		loaded:Play()
		track = loaded
	end

	local momentum = Vector3.zero
	local lastFlat = Vector3.zero
	local bank = 0

	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		local frames = deltaTime * REFERENCE_RATE
		if frames <= 0 then
			return
		end

		local cameraCFrame = Workspace.CurrentCamera.CFrame
		local look = cameraCFrame.LookVector
		local move = humanoid.MoveDirection

		local wanted = Vector3.zero
		local moving = move.Magnitude > 0.01
		if moving then
			-- 1 moving along the camera, 0 sideways, -1 toward it: flying backward while
			-- looking up goes down.
			local forward = 1
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude > 0.0001 then
				local cosine = math.clamp(flatLook.Unit:Dot(move.Unit), -1, 1)
				forward = 1 - 2 * math.acos(cosine) / math.pi
			end
			wanted = Vector3.new(move.X, look.Y * forward, move.Z) * topSpeed
		end

		local keep = KEEP ^ frames
		momentum = momentum * keep + wanted * (1 - keep)
		if not moving and momentum.Magnitude < 1 then
			momentum = Vector3.zero
		end

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
			local bankKeep = BANK_KEEP ^ frames
			bank = bank * bankKeep + turn * (1 - bankKeep) * (BANK_GAIN / (1 - BANK_KEEP))
		end

		local speed = momentum.Magnitude
		if speed < 1 then
			gyro.CFrame = cameraCFrame
		else
			local lean = MAX_LEAN * math.min(speed, LEAN_SPEED) / LEAN_SPEED
			gyro.CFrame = CFrame.lookAt(Vector3.zero, momentum)
				* CFrame.Angles(0, 0, bank * BANK_ANGLE)
				* CFrame.Angles(-lean, 0, 0)
		end
		mover.Velocity = momentum
	end)

	return function()
		connection:Disconnect()
		if track then
			track:Stop()
		end
		carrier:Destroy()
	end
end
