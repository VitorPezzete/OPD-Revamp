--!strict
--[[
	Chilly fruit - Ice Wave, while the key is held: a ball of frost growing on the hand.
	Status value: "<Right|Left>|<max size>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Chilly.Power5.ChillyFreezeEffect
	(a part with a "Mesh" and an "Attachment.Freeze" emitter), welded one stud below the
	arm's center. Its mesh grows linearly from 0.1 to the max size over 3 s.

	First fruit color on the part, both on the emitter; dark while armament haki is on.
	Owner only, as the legacy client did: the charge animation (wind-up clip, then the
	held clip) and, when the status ends, one turn towards the mouse and the wave clip
	(FruitAnims.Wave*) played 32 times faster; not when the charge was cut short by a
	stun, a seal or death.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_TIME = 3
local START_SCALE = Vector3.new(0.1, 0.1, 0.1)
local WELD_OFFSET = CFrame.new(0, -1, 0)
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local HAKI_SEQUENCE = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local STUN_ATTRIBUTE = "Stunned"
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 32

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"
	local maxSize = tonumber(fields[2]) or 1
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local frost: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil

	local template = EffectAssets.FindFruit("Chilly", "Power5", "ChillyFreezeEffect")
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if template and template:IsA("BasePart") and arm and arm:IsA("BasePart") then
		local ball = template:Clone()
		for _, descendant in ball:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			end
		end
		ball.Anchored = false
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Massless = true
		ball.CFrame = arm.CFrame * WELD_OFFSET

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = ball
		weld.C0 = WELD_OFFSET
		weld.Parent = ball

		local emitter = ball:FindFirstChild("Freeze", true)
		local authoredColor = ball.Color
		local authoredSequence = if emitter and emitter:IsA("ParticleEmitter") then emitter.Color else nil

		local function paint()
			local color = authoredColor
			local sequence = authoredSequence
			if character:GetAttribute(HAKI_ATTRIBUTE) then
				color, sequence = HAKI_COLOR, HAKI_SEQUENCE
			elseif primary and secondary then
				color, sequence = primary, FruitColor.ToSequence(primary, secondary)
			end
			ball.Color = color
			if emitter and emitter:IsA("ParticleEmitter") and sequence then
				emitter.Color = sequence
			end
		end
		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

		local mesh = ball:FindFirstChildWhichIsA("DataModelMesh")
		if mesh then
			mesh.Scale = START_SCALE
			TweenService:Create(mesh, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear), {
				Scale = Vector3.new(maxSize, maxSize, maxSize),
			}):Play()
		end

		ball.Parent = arm
		frost = ball
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
		local windUp = load(if left then anims.WaveLeftCharge else anims.WaveRightCharge)
		local held = load(if left then anims.WaveLeftCharged else anims.WaveRightCharged)
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		if hakiConnection then
			hakiConnection:Disconnect()
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
		if released then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and humanoid and not humanoid.Sit then
				local position = root.Position
				local target = Players.LocalPlayer:GetMouse().Hit.Position
				local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
				if flat.Magnitude > 0.1 then
					root.CFrame = CFrame.lookAt(position, position + flat)
				end
			end
			if foundAnimator then
				local anims = AnimationConfig.FruitAnims
				Animations.Play(
					foundAnimator,
					if left then anims.WaveLeft else anims.WaveRight,
					RELEASE_FADE,
					1,
					RELEASE_SPEED
				)
			end
		end
		if frost then
			frost:Destroy()
		end
	end
end
