--!strict
--[[
	Phoenix fruit - Fly.
	Status value: "<speed in studs per second>|<fruit color string>".

	Everyone: a wing of flames on each arm.
	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.PhoenixWing.Wing (a part with
	a ParticleEmitter), welded to the centre of the arm as in the legacy game. Colors:
	dark with armament haki, the fruit colors when it has an aura, else blue to yellow.

	Owner only: the flight itself. The character faces where the camera looks, hovers
	with no input and moves along the walk input at the status speed; forward / backward
	input adds the camera pitch on top of it (the legacy target was the walk direction
	plus the look height, not normalised, so climbing does not slow the flight down).
	One of nine clips (AnimationConfig.FruitAnims.Phoenix*) is played at speed 3 according
	to the input direction relative to the camera, as in the legacy script, which drove a
	BodyPosition chased 10000 studs ahead instead.

	A BodyPosition does not cancel gravity: its damping (1250) only limits the fall, so
	the legacy phoenix sank at weight / damping studs per second (2 to 3 for a
	character), hovering or not. The same sink is added to the flight velocity.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_SPEED = 480
local FLIGHT_FORCE = 4000000
-- Damping of the legacy BodyPosition (FlareJet).
local DAMPING = 1250
local ANIMATION_SPEED = 3
local ANIMATION_FADE = 0.1
-- Input closer than this to an axis (as a cosine) counts as "not on that axis".
local AXIS_THRESHOLD = 0.38

local ARMS = { "Right Arm", "Left Arm" }
local HAKI_ATTRIBUTE = "Haki"
local HAKI_SEQUENCE = ColorSequence.new(Color3.fromRGB(16, 0, 26), Color3.fromRGB(60, 0, 97))
local DEFAULT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.798, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.926, Color3.fromRGB(230, 250, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)),
})

-- Clip by (forward, side) input, each -1 / 0 / 1: index (forward + 1) * 3 + (side + 1) + 1.
local CLIPS = {
	"PhoenixSA",
	"PhoenixS",
	"PhoenixSD",
	"PhoenixA",
	"PhoenixIdle",
	"PhoenixD",
	"PhoenixWA",
	"PhoenixForward",
	"PhoenixWD",
}

local function addWings(character: Model, colors: string): () -> ()
	local template = EffectAssets.FindFruit("Phoenix", "PhoenixWing", "Wing")
	if not template or not template:IsA("BasePart") then
		return function() end
	end

	local primary, secondary = FruitColor.Parse(colors)
	local normal = DEFAULT_SEQUENCE
	if primary and secondary then
		normal = ColorSequence.new({
			ColorSequenceKeypoint.new(0, primary),
			ColorSequenceKeypoint.new(0.798, primary),
			ColorSequenceKeypoint.new(0.926, secondary),
			ColorSequenceKeypoint.new(1, secondary),
		})
	end

	local wings: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	for _, armName in ARMS do
		local arm = character:FindFirstChild(armName)
		if not arm or not arm:IsA("BasePart") then
			continue
		end

		local wing = template:Clone()
		wing.Name = "PhoenixFlyWing"
		wing.Anchored = false
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.Massless = true
		for _, descendant in wing:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("ParticleEmitter") then
				table.insert(emitters, descendant)
			end
		end
		wing.CFrame = arm.CFrame

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = wing
		weld.Parent = wing

		wing.Parent = character
		table.insert(wings, wing)
	end

	local function recolor()
		local sequence = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_SEQUENCE else normal
		for _, emitter in emitters do
			emitter.Color = sequence
		end
	end
	recolor()
	local connection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(recolor)

	return function()
		connection:Disconnect()
		for _, wing in wings do
			wing:Destroy()
		end
	end
end

local function sign(value: number): number
	return if value > AXIS_THRESHOLD then 1 elseif value < -AXIS_THRESHOLD then -1 else 0
end

local function pickClip(move: Vector3, camera: CFrame): string
	if move.Magnitude < 0.01 then
		return "PhoenixIdle"
	end

	local look, right = camera.LookVector, camera.RightVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatRight = Vector3.new(right.X, 0, right.Z)
	if flatLook.Magnitude < 0.001 or flatRight.Magnitude < 0.001 then
		return "PhoenixForward"
	end

	local forward = sign(move.Unit:Dot(flatLook.Unit))
	local side = sign(move.Unit:Dot(flatRight.Unit))
	if forward == 0 and side == 0 then
		return "PhoenixForward"
	end
	return CLIPS[(forward + 1) * 3 + (side + 1) + 1]
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
	attachment.Name = "PhoenixFlight"
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

	-- Clips are taken from the shared cache the first time their direction is used.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local sharedClips = (AnimationConfig :: any).FruitAnims
	local tracks: { [string]: AnimationTrack } = {}
	local currentClip: string? = nil
	local currentTrack: AnimationTrack? = nil

	local function play(clip: string)
		if clip == currentClip then
			return
		end
		currentClip = clip
		if currentTrack then
			currentTrack:Stop(ANIMATION_FADE)
			currentTrack = nil
		end

		local track = tracks[clip]
		if not track then
			local animationId = if type(sharedClips) == "table" then sharedClips[clip] else nil
			if not animator or type(animationId) ~= "string" then
				return
			end
			track = Animations.Get(animator, animationId)
			tracks[clip] = track
		end
		track.Looped = true
		track:Play(ANIMATION_FADE, 1, ANIMATION_SPEED)
		currentTrack = track
	end

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local look = camera.CFrame.LookVector
		align.CFrame = camera.CFrame.Rotation

		local sink = Vector3.new(0, -root.AssemblyMass * Workspace.Gravity / DAMPING, 0)
		local move = humanoid.MoveDirection
		play(pickClip(move, camera.CFrame))
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
		for _, track in tracks do
			track:Stop(ANIMATION_FADE)
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local speed = tonumber(fields[1]) or DEFAULT_SPEED
	local removeWings = addWings(character, fields[2] or "")
	local stopFlight = if isLocal then startFlight(character, speed) else nil

	return function()
		if stopFlight then
			stopFlight()
		end
		removeWings()
	end
end
