--!strict
--[[
	Chilly fruit - Freezing Punch, while the key is held: the fist cased in ice.
	Status value: "<Right|Left>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Chilly.Power2.ChillyFreezePunch
	(a union), welded on the arm and painted with the first fruit color.

	Owner only, as the legacy client did:
	- the charge animation (wind-up clip, then the held clip), replicated by the Animator;
	- the character keeps facing the mouse;
	- when the status ends, the punch clip (FruitAnims.Punch1*Punch) played 30 times
	  faster, whatever the charge; not when the charge was cut short by a stun, a seal
	  or death.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local RENDER_STEP_NAME = "ChillyPunchFacing"
local STUN_ATTRIBUTE = "Stunned"
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 30

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"
	local primary = FruitColor.Parse(fields[2] or "")

	local hand: BasePart? = nil
	local template = EffectAssets.FindFruit("Chilly", "Power2", "ChillyFreezePunch")
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if template and template:IsA("BasePart") and arm and arm:IsA("BasePart") then
		local ice = template:Clone()
		for _, descendant in ice:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		ice.Anchored = false
		ice.CanCollide = false
		ice.CanQuery = false
		ice.CanTouch = false
		ice.Massless = true
		ice.CFrame = arm.CFrame
		if primary then
			ice.Color = primary
		end

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = ice
		weld.Parent = ice

		ice.Parent = arm
		hand = ice
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local foundAnimator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if isLocal and foundAnimator then
		local animator: Animator = foundAnimator
		local function load(animationId: string): AnimationTrack
			local track = Animations.Get(animator, animationId)
			table.insert(tracks, track)
			return track
		end

		local anims = AnimationConfig.FruitAnims
		local windUp = load(if left then anims.Punch1LeftCharge else anims.Punch1RightCharge)
		local held = load(if left then anims.Punch1LeftCharged else anims.Punch1RightCharged)
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	end

	local facing = false
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if isLocal and humanoid and foundRoot and foundRoot:IsA("BasePart") then
		-- Typed copies: the closure below cannot rely on the narrowing above.
		local facingHumanoid: Humanoid, root: BasePart = humanoid, foundRoot
		local mouse = Players.LocalPlayer:GetMouse()
		facing = true
		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
			if facingHumanoid.Sit then
				return
			end
			local position = root.Position
			local target = mouse.Hit.Position
			local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
			if flat.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(position, position + flat)
			end
		end)
	end

	return function()
		active = false
		if facing then
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end

		local released = isLocal
			and humanoid ~= nil
			and humanoid.Health > 0
			and character:IsDescendantOf(game)
			and not character:GetAttribute(STUN_ATTRIBUTE)
			and not character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled)
		if foundAnimator and released then
			local anims = AnimationConfig.FruitAnims
			Animations.Play(
				foundAnimator,
				if left then anims.Punch1LeftPunch else anims.Punch1RightPunch,
				RELEASE_FADE,
				1,
				RELEASE_SPEED
			)
		end
		if hand then
			hand:Destroy()
		end
	end
end
