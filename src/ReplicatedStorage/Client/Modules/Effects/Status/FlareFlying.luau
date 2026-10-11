--!strict
--[[
	Flare fruit - Jet.
	Status value: "<speed in studs per second>|<fruit color string>".

	Everyone: fire and a light on both legs.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Flare.Power1.FlareFly (a
	ParticleEmitter, both fruit colors) and FlareLight (a PointLight, first color).

	Owner only: the flight itself. The character faces where the camera looks, hovers
	with no input and moves along the walk input at the status speed; forward / backward
	input adds the camera pitch on top (looking up while walking forward climbs), without
	slowing the horizontal part, as the legacy target point did.

	The legacy script did this with a BodyPosition chased 10000 studs ahead and set the
	torso CFrame every frame. Its flying pose is the Animation stored inside that
	BodyPosition (Assets.Models.Fruits._Shared.FlareJet), played over-weighted; the shared
	FruitAnims.FlyingT clip stands in when the asset is missing or cannot be loaded here.
]]
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_SPEED = 480
local FLIGHT_FORCE = 4000000
local LEGS = { "Right Leg", "Left Leg" }
local JET_WEIGHT = 3
local JET_WEIGHT_FADE = 0.1

-- nil until the jet pose has been fetched once; false when this place cannot load it.
local jetAvailable: boolean? = nil

local function addFire(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local flame = EffectAssets.FindFruit("Flare", "Power1", "FlareFly")
	local light = EffectAssets.FindFruit("Flare", "Power1", "FlareLight")
	local primary, secondary = FruitColor.Parse(colors)

	for _, legName in LEGS do
		local leg = character:FindFirstChild(legName)
		if not leg or not leg:IsA("BasePart") then
			continue
		end
		if flame and flame:IsA("ParticleEmitter") then
			local clone = flame:Clone()
			if primary and secondary then
				clone.Color = FruitColor.ToSequence(primary, secondary)
			end
			clone.Enabled = true
			clone.Parent = leg
			table.insert(created, clone)
		end
		if light and light:IsA("PointLight") then
			local clone = light:Clone()
			if primary and secondary then
				clone.Color = primary
			end
			clone.Parent = leg
			table.insert(created, clone)
		end
	end
	return created
end

local function jetAnimationId(): string?
	local jet = EffectAssets.FindFruit("_Shared", "FlareJet")
	local animation = jet and jet:FindFirstChildOfClass("Animation")
	local digits = animation and string.match(animation.AnimationId, "%d+")
	return if digits then `rbxassetid://{digits}` else nil
end

-- Returns the stop function of the flying pose.
local function playPose(animator: Animator): () -> ()
	local active = true
	local track: AnimationTrack? = nil

	local function playFallback()
		local animationId = (AnimationConfig :: any).FruitAnims.FlyingT
		if type(animationId) == "string" then
			local loaded = Animations.Get(animator, animationId)
			loaded.Looped = true
			loaded:Play()
			track = loaded
		end
	end

	local jetId = if jetAvailable ~= false then jetAnimationId() else nil
	if jetId then
		local jetTrack = Animations.Get(animator, jetId)
		jetTrack:Play()
		jetTrack:AdjustWeight(JET_WEIGHT, JET_WEIGHT_FADE)
		track = jetTrack

		if jetAvailable == nil then
			task.spawn(function()
				local probe = Instance.new("Animation")
				probe.AnimationId = jetId
				local loaded = true
				pcall(function()
					ContentProvider:PreloadAsync({ probe }, function(_, status: Enum.AssetFetchStatus)
						if status == Enum.AssetFetchStatus.Failure then
							loaded = false
						end
					end)
				end)
				probe:Destroy()
				jetAvailable = loaded
				if not loaded and active and track == jetTrack then
					jetTrack:Stop()
					playFallback()
				end
			end)
		end
	else
		playFallback()
	end

	return function()
		active = false
		if track then
			track:Stop()
		end
	end
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
	attachment.Name = "FlareFlight"
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
	local stopPose = if animator then playPose(animator) else nil

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local look = camera.CFrame.LookVector
		align.CFrame = camera.CFrame.Rotation

		local move = humanoid.MoveDirection
		if move.Magnitude < 0.01 then
			velocity.VectorVelocity = Vector3.zero
			return
		end

		-- Input measured against the camera: 1 straight ahead, 0 sideways, -1 backwards.
		local flatLook = Vector3.new(look.X, 0, look.Z)
		local forward = 1
		if flatLook.Magnitude > 0.001 then
			local ahead = move.Unit:Dot(flatLook.Unit)
			forward = 1 - 2 * math.acos(math.clamp(ahead, -1, 1)) / math.pi
		end

		velocity.VectorVelocity = Vector3.new(move.X, look.Y * forward, move.Z) * speed
	end)

	return function()
		connection:Disconnect()
		attachment:Destroy()
		humanoid.AutoRotate = previousAutoRotate
		if stopPose then
			stopPose()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local speed = tonumber(fields[1]) or DEFAULT_SPEED
	local created = addFire(character, fields[2] or "")
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
