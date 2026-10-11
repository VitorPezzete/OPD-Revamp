--!strict
--[[
	Rumble fruit - El Thor while the key is held. Status value: "Right" or "Left", the
	casting hand.

	Nothing is drawn on the hand (the legacy game showed nothing either). Owner only:
	- the charge pose: the wind-up clip, then the held clip (FruitAnims.BeamCharge* then
	  BeamCharged*), replicated by the Animator;
	- the character keeps facing the mouse, as the legacy "looker" did;
	- when the status ends, the release clip (FruitAnims.BeamRelease*) played 30 times
	  faster, as the legacy client did; not when the charge was cut short by a stun, a
	  seal or death.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local RENDER_STEP_NAME = "RumbleThorFacing"
local STUN_ATTRIBUTE = "Stunned"
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 30

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return noop
	end
	-- Typed copies: the closures below cannot rely on the narrowing above.
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot
	local animator = humanoid:FindFirstChildOfClass("Animator")

	local left = value == "Left"
	local anims = AnimationConfig.FruitAnims

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil
	if animator then
		local windUp = Animations.Get(animator, if left then anims.BeamChargeLeft else anims.BeamChargeRight)
		local held = Animations.Get(animator, if left then anims.BeamChargedLeft else anims.BeamChargedRight)
		tracks = { windUp, held }
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	end

	local mouse = Players.LocalPlayer:GetMouse()
	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
		if humanoid.Sit then
			return
		end
		local position = root.Position
		local target = mouse.Hit.Position
		local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if flat.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(position, position + flat)
		end
	end)

	return function()
		active = false
		RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end

		local released = humanoid.Health > 0
			and character:IsDescendantOf(game)
			and not character:GetAttribute(STUN_ATTRIBUTE)
			and not character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled)
		if animator and released then
			Animations.Play(
				animator,
				if left then anims.BeamReleaseLeft else anims.BeamReleaseRight,
				RELEASE_FADE,
				1,
				RELEASE_SPEED
			)
		end
	end
end
