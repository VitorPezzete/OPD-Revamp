--!strict
--[[
	Hollow fruit - Projection: the ghost body, for everyone, and its flight controls for
	the owner. The real body is rooted by the server and plays the "Projection" pose.

	Status value: "<fruit slot>|<ability slot>|<speed>|<range>|<colors>".
	Other attributes read from the character (they are not effects of their own):
	- "HollowGhost" (Vector3): where the server says the ghost is;
	- "HollowFaded": the ghost is invisible (Fade ability).
	Template: ReplicatedStorage.Assets.Models.Fruits.Hollow.Power1.GhostBody (an R6 rig).

	The ghost wears copies of the caster's hair, shirt, sleeves and trouser legs
	(<character>.Clothes), as the legacy one did; its skin and face are the template's.
	It is driven by an AnimationController instead of its Humanoid: a Humanoid keeps its
	torso and head solid, and the legacy ghost collided with nothing.

	Owner: the ghost is flown here, anchored and moved by CFrame. It follows the move
	direction, the camera pitch adding a climb or a dive on top when moving forward or
	backward (legacy: up to 1.41x the speed looking straight up), with the legacy
	0.96-per-frame momentum made frame-rate independent. The camera follows the ghost.
	Its position is reported to the server eight times a second as the ability's
	secondary input (phase 3); the server checks speed and range and republishes it as
	"HollowGhost". The same range limit is applied here so reports are not refused.

	Pose (the legacy BodyGyro): standing still the ghost faces where the camera looks;
	moving, it turns along its velocity and leans forward up to lying flat at 50 studs
	per second, banking into turns.

	Everyone else: the ghost glides toward "HollowGhost", posed from that motion.

	A faded ghost is fully hidden for others and see-through for its owner, who still
	has to steer it (the legacy hid it from the owner too).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GHOST_ATTRIBUTE = "HollowGhost"
local FADED_ATTRIBUTE = "HollowFaded"

local PHASE_ACTION = 3
local REPORT_INTERVAL = 0.125
-- Share of the velocity kept each 1/60 s.
local DAMPING = 0.96
local FOLLOW_SPEED = 8
local FADE_TIME = 0.5
local OWNER_FADED_TRANSPARENCY = 0.7
local START_OFFSET = CFrame.new(0, 2, 0)
local ANIMATION_FADE = 0.2
-- Speed at which the ghost lies flat, and how fast it turns to its pose.
local FLAT_SPEED = 50
local TURN_RATE = 12
local BANK = -20
-- Pieces of <character>.Clothes the ghost copies.
local WORN = { Hair = true, Shirt = true, Arm1 = true, Arm2 = true, Leg1 = true, Leg2 = true }

-- Copies of the caster's clothing, welded on the ghost's limbs like the originals are.
local function dress(character: Model, ghost: Model)
	local clothes = character:FindFirstChild("Clothes")
	if not clothes then
		return
	end
	for _, piece in clothes:GetChildren() do
		local fit = piece:FindFirstChild("Fit")
		if not piece:IsA("BasePart") or not WORN[piece.Name] or not fit or not fit:IsA("Weld") then
			continue
		end
		local worn = fit.Part0
		local limb = worn and ghost:FindFirstChild(worn.Name)
		if limb and limb:IsA("BasePart") then
			local copy = piece:Clone()
			for _, descendant in copy:GetDescendants() do
				if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
					descendant:Destroy()
				end
			end
			local weld = Instance.new("Weld")
			weld.Part0 = limb
			weld.Part1 = copy
			weld.C0 = fit.C0
			weld.Parent = copy
			copy.Parent = ghost
		end
	end
end

-- Target rotation of a ghost moving at `velocity`; nil when it is standing still.
local function pose(velocity: Vector3, tilt: number): CFrame?
	local speed = velocity.Magnitude
	if speed < 1 then
		return nil
	end
	-- Straight up or down has no heading for lookAt's default up vector.
	local up = if math.abs(velocity.Unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(Vector3.zero, velocity, up)
		* CFrame.Angles(0, 0, tilt * BANK)
		* CFrame.Angles(-math.pi / 2 * math.min(speed, FLAT_SPEED) / FLAT_SPEED, 0, 0)
end

local function noop() end

local function playLooped(animator: Animator, animationId: string): AnimationTrack
	local track = Animations.Get(animator, animationId)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(ANIMATION_FADE)
	return track
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local speed = tonumber(fields[3]) or 0
	local range = tonumber(fields[4]) or 0

	local template = EffectAssets.FindFruit("Hollow", "Power1", "GhostBody")
	local body = character:FindFirstChild("HumanoidRootPart")
	if not template or not template:IsA("Model") or not body or not body:IsA("BasePart") then
		return noop
	end

	local ghost = template:Clone()
	local ghostRoot = ghost:FindFirstChild("HumanoidRootPart")
	if not ghostRoot or not ghostRoot:IsA("BasePart") then
		ghost:Destroy()
		return noop
	end
	ghost.PrimaryPart = ghostRoot
	dress(character, ghost)

	-- Legacy flight movers and scripts have no place on an anchored, client-only model.
	local faders: { Instance } = {}
	for _, descendant in ghost:GetDescendants() do
		if
			descendant:IsA("BodyMover")
			or descendant:IsA("Constraint")
			or descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Humanoid")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			table.insert(faders, descendant)
		elseif descendant:IsA("Decal") then
			table.insert(faders, descendant)
		end
	end
	ghostRoot.Anchored = true

	local published = character:GetAttribute(GHOST_ATTRIBUTE)
	local position: Vector3 = if typeof(published) == "Vector3" then published else (body.CFrame * START_OFFSET).Position
	local rotation = body.CFrame.Rotation
	ghost:PivotTo(CFrame.new(position) * rotation)
	ghost.Parent = World.Effects()

	local tracks: { AnimationTrack } = {}
	local ghostController = Instance.new("AnimationController")
	local ghostAnimator = Instance.new("Animator")
	ghostAnimator.Parent = ghostController
	ghostController.Parent = ghost
	table.insert(tracks, playLooped(ghostAnimator, AnimationConfig.Fruits.Hollow.GhostBody))

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if isLocal and humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			table.insert(tracks, playLooped(animator, AnimationConfig.Fruits.Hollow.Projection))
		end
	end

	local fadedAmount = 0
	local function applyFade(deltaTime: number)
		local goal = 0
		if character:GetAttribute(FADED_ATTRIBUTE) then
			goal = if isLocal then OWNER_FADED_TRANSPARENCY else 1
		end
		if fadedAmount == goal then
			return
		end

		local change = deltaTime / FADE_TIME
		fadedAmount = if fadedAmount < goal
			then math.min(goal, fadedAmount + change)
			else math.max(goal, fadedAmount - change)
		for _, instance in faders do
			(instance :: any).LocalTransparencyModifier = fadedAmount
		end
	end

	local camera = Workspace.CurrentCamera
	local abilityService = if isLocal and fruitSlot and abilitySlot then Knit.GetService("AbilityService") else nil
	if abilityService and camera then
		local ghostHead = ghost:FindFirstChild("Head")
		camera.CameraSubject = if ghostHead and ghostHead:IsA("BasePart") then ghostHead else ghostRoot
	end

	local velocity = Vector3.zero
	local sinceReport = 0
	local tilt = 0
	local lastFlat = Vector3.zero
	-- Someone else's ghost: its motion, measured between two published positions.
	local seenGoal = position
	local seenAt = os.clock()
	local seenVelocity = Vector3.zero

	local function turn(target: CFrame?, deltaTime: number)
		if target then
			rotation = rotation:Lerp(target, math.clamp(TURN_RATE * deltaTime, 0, 1))
		end
		ghost:PivotTo(CFrame.new(position) * rotation)
	end

	local connection = RunService.RenderStepped:Connect(function(deltaTime: number)
		applyFade(deltaTime)

		if not abilityService then
			-- Someone else's ghost: glide to where the server last saw it.
			local goal = character:GetAttribute(GHOST_ATTRIBUTE)
			if typeof(goal) == "Vector3" then
				local now = os.clock()
				if goal ~= seenGoal then
					seenVelocity = (goal - seenGoal) / math.max(now - seenAt, REPORT_INTERVAL)
					seenGoal, seenAt = goal, now
				elseif now - seenAt > REPORT_INTERVAL * 3 then
					seenVelocity = Vector3.zero
				end
				position = position:Lerp(goal, math.clamp(FOLLOW_SPEED * deltaTime, 0, 1))
				turn(pose(seenVelocity, 0), deltaTime)
			end
			return
		end

		local direction = Vector3.zero
		local move = if humanoid then humanoid.MoveDirection else Vector3.zero
		local look = if camera then camera.CFrame.LookVector else rotation.LookVector
		if move.Magnitude > 0.05 then
			local flatLook = Vector3.new(look.X, 0, look.Z)
			-- 1 moving where the camera looks, -1 moving back, 0 strafing: linear in the
			-- angle between the two, as the legacy flight computed it.
			local forward = 0
			if flatLook.Magnitude > 1e-3 then
				forward = 1 - 2 * math.acos(math.clamp(move.Unit:Dot(flatLook.Unit), -1, 1)) / math.pi
			end
			direction = Vector3.new(move.X, look.Y * forward, move.Z)
		end

		local keep = DAMPING ^ (deltaTime * 60)
		velocity = velocity * keep + direction * speed * (1 - keep)
		if velocity.Magnitude < 1 and direction == Vector3.zero then
			velocity = Vector3.zero
		end
		position += velocity * deltaTime

		local fromBody = position - body.Position
		if fromBody.Magnitude > range then
			position = body.Position + fromBody.Unit * range
			velocity = Vector3.zero
		end

		-- Bank: the turn made this frame (sine of the heading change, scaled to 1/60 s),
		-- smoothed with the legacy per-frame constants.
		local frames = deltaTime * 60
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local turned = 0
		if flat.Magnitude > 1e-3 and lastFlat.Magnitude > 1e-3 and frames > 0 then
			turned = flat.Unit:Cross(lastFlat.Unit).Y / frames
		end
		lastFlat = flat
		if math.abs(turned) > 0.06 or math.abs(turned) < 0.0001 then
			tilt *= 0.9 ^ frames
		else
			local keepTilt = 0.77 ^ frames
			tilt = tilt * keepTilt + turned * (0.25 / 0.23) * (1 - keepTilt)
		end

		local target = pose(velocity, tilt)
		if not target and camera then
			target = camera.CFrame.Rotation
		end
		turn(target, deltaTime)

		sinceReport += deltaTime
		if sinceReport >= REPORT_INTERVAL then
			sinceReport = 0
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, position)
		end
	end)

	return function()
		connection:Disconnect()
		for _, track in tracks do
			track:Stop(ANIMATION_FADE)
		end
		ghost:Destroy()

		if abilityService then
			local currentCamera = Workspace.CurrentCamera
			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if currentCamera and currentHumanoid then
				currentCamera.CameraSubject = currentHumanoid
			end
		end
	end
end
