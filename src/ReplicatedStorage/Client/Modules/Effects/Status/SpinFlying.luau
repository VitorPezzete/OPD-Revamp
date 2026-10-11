--!strict
--[[
	Spin fruit - Copter.
	Status value: "<speed in studs per second>|<fruit color string>".

	Everyone: a blade welded on the torso and a small one under each leg.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Spin.Power1.SpinBlade / SpinBladeSmall.

	Owner only: the flight itself. The character faces where the camera looks, hovers
	with no input and moves along the walk input; forward / backward input also follows
	the camera pitch, so looking up while walking forward climbs. One of nine looped
	animations is picked from the input direction relative to the camera.

	The legacy script did this with a BodyPosition chased 10000 studs ahead and a
	900-line nested if to choose the animation. That BodyPosition is the shared FlareJet
	resource (Assets.Models.Fruits._Shared.FlareJet).

	A BodyPosition does not fight gravity unless its goal is above the part: hovering
	(goal = where the character is) only damped the fall, so the character kept sinking
	at weight / D studs per second (about 2), and the same sink was added to any flight.
	It is reproduced with the D of the FlareJet asset (1250 when the asset is missing).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local DEFAULT_SPEED = 480
-- The server sends the speed for a damping of 1250 (BodyPosition default).
local DEFAULT_DAMPING = 1250
local FLIGHT_FORCE = 4000000
local ANIMATION_SPEED = 3
local ANIMATION_FADE = 0.1

local BLADE_ROTATION = CFrame.Angles(0, 0, math.rad(90))
local BLADES = {
	{ Limb = "Torso", Template = "SpinBlade", Offset = CFrame.new(0, 1.05, 0) * BLADE_ROTATION },
	{ Limb = "Right Leg", Template = "SpinBladeSmall", Offset = CFrame.new(0, -0.75, 0) * BLADE_ROTATION },
	{ Limb = "Left Leg", Template = "SpinBladeSmall", Offset = CFrame.new(0, -0.75, 0) * BLADE_ROTATION },
}

local IDLE_ANIMATION = "SpinIdle"
-- Clockwise from "forward", one entry per 45 degrees of input direction.
local DIRECTION_ANIMATIONS = { "SpinForward", "SpinWD", "SpinD", "SpinSD", "SpinS", "SpinSA", "SpinA", "SpinWA" }

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

-- Damping of the legacy BodyPosition (BodyPosition default when the asset is missing).
local function flightDamping(): number
	local jet = findAsset("Models", "Fruits", "_Shared", "FlareJet")
	return if jet and jet:IsA("BodyPosition") and jet.D > 0 then jet.D else DEFAULT_DAMPING
end

local function parseValue(value: any): (number, string)
	if type(value) ~= "string" then
		return DEFAULT_SPEED, ""
	end
	local speed, colors = string.match(value, "^(%d+)|(.*)$")
	return tonumber(speed) or DEFAULT_SPEED, (colors or "") :: string
end

local function addBlades(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local primary = FruitColor.Parse(colors)

	for _, blade in BLADES do
		local limb = character:FindFirstChild(blade.Limb)
		local template = findAsset("Models", "Fruits", "Spin", "Power1", blade.Template)
		if limb and limb:IsA("BasePart") and template and template:IsA("BasePart") then
			local part = template:Clone()
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if primary then
				part.Color = primary
			end

			local weld = Instance.new("Weld")
			weld.Part0 = limb
			weld.Part1 = part
			weld.C0 = blade.Offset
			weld.Parent = part

			part.Parent = limb
			table.insert(created, part)
		end
	end
	return created
end

-- Returns the cleanup of the local flight, or nil when the character cannot fly.
local function startFlight(character: Model, speed: number): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot
	local damping = flightDamping()
	speed *= DEFAULT_DAMPING / damping

	local attachment = Instance.new("Attachment")
	attachment.Name = "SpinFlight"
	attachment.Parent = root

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

	local previousAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local tracks: { [string]: AnimationTrack } = {}
	local currentAnimation: string? = nil

	local function getTrack(name: string): AnimationTrack?
		local id = (AnimationConfig.FruitAnims :: any)[name]
		if tracks[name] or not animator or type(id) ~= "string" then
			return tracks[name]
		end

		local track = Animations.Get(animator, id)
		tracks[name] = track
		return track
	end

	local function playAnimation(name: string)
		if currentAnimation == name then
			return
		end
		if currentAnimation and tracks[currentAnimation] then
			tracks[currentAnimation]:Stop(ANIMATION_FADE)
		end
		currentAnimation = name

		local track = getTrack(name)
		if track then
			track:Play(ANIMATION_FADE, 1, ANIMATION_SPEED)
		end
	end

	playAnimation(IDLE_ANIMATION)

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end

		local look = camera.CFrame.LookVector
		align.CFrame = CFrame.lookAt(Vector3.zero, look)

		local sink = Vector3.new(0, -root.AssemblyMass * Workspace.Gravity / damping, 0)
		local move = humanoid.MoveDirection
		if move.Magnitude < 0.01 then
			velocity.VectorVelocity = sink
			playAnimation(IDLE_ANIMATION)
			return
		end

		-- Input measured against the camera: 1 straight ahead, 0 sideways, -1 backwards.
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local flatRight = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
		local forward = 1
		local angle = 0
		if flatLook.Magnitude > 0.001 and flatRight.Magnitude > 0.001 then
			local ahead = move.Unit:Dot(flatLook.Unit)
			local sideways = move.Unit:Dot(flatRight.Unit)
			forward = 1 - 2 * math.acos(math.clamp(ahead, -1, 1)) / math.pi
			angle = math.atan2(sideways, ahead)
		end

		velocity.VectorVelocity = Vector3.new(move.X, look.Y * forward, move.Z) * speed + sink
		playAnimation(DIRECTION_ANIMATIONS[math.round(angle / (math.pi / 4)) % 8 + 1])
	end)

	return function()
		connection:Disconnect()
		attachment:Destroy()
		humanoid.AutoRotate = previousAutoRotate
		for _, track in tracks do
			track:Stop(ANIMATION_FADE)
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local speed, colors = parseValue(value)
	local blades = addBlades(character, colors)
	local stopFlight = if isLocal then startFlight(character, speed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		for _, blade in blades do
			blade:Destroy()
		end
	end
end
