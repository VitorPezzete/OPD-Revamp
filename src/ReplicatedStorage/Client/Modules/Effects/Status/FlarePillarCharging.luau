--!strict
--[[
	Flare fruit - Flame Pillar while charging: fire around the punching hand.
	Status value: "<Right|Left>|<fruit color string>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power5["Flare Fire2"] (a part
	holding the emitter), welded half a stud under the centre of the arm as in the
	legacy game.

	Both fruit colors on the emitter; dark for as long as armament haki is on (the legacy
	fire followed the haki live), the authored colors otherwise.
	Owner only: the body keeps facing the mouse (legacy "P5Looker") and the charge
	animation plays: the wind-up clip at a quarter of its speed, then the held loop. The
	punch belongs to the FlarePillar one-shot.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local RENDER_STEP_NAME = "FlarePillarFacing"
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local HAND_OFFSET = CFrame.new(0, 0.5, 0)
local WIND_UP_FADE = 0.1
local WIND_UP_SPEED = 0.25

-- Returns the cleanup of the hand fire, or nil when it could not be built.
local function addFire(character: Model, left: boolean, colors: string): (() -> ())?
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local template = EffectAssets.FindFruit("Flare", "Power5", "Flare Fire2")
	if not arm or not arm:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return nil
	end

	local fire = template:Clone()
	fire.Anchored = false
	fire.CanCollide = false
	fire.CanQuery = false
	fire.CanTouch = false
	fire.Massless = true

	local authored: { [ParticleEmitter]: ColorSequence } = {}
	for _, descendant in fire:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") then
			authored[descendant] = descendant.Color
		end
	end

	local primary, secondary = FruitColor.Parse(colors)
	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		for emitter, color in authored do
			emitter.Color = if haki
				then HAKI_COLOR
				elseif primary and secondary then FruitColor.ToSequence(primary, secondary)
				else color
		end
	end
	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

	local weld = Instance.new("Weld")
	weld.Part0 = arm
	weld.Part1 = fire
	weld.C1 = HAND_OFFSET
	weld.Parent = fire

	fire.Parent = arm

	return function()
		hakiConnection:Disconnect()
		fire:Destroy()
	end
end

-- Returns the cleanup of the owner's animation and facing, or nil.
local function startCharging(character: Model, left: boolean): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	-- Typed copies: the closures below cannot rely on the narrowing above.
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local foundAnimator = humanoid:FindFirstChildOfClass("Animator")
	if foundAnimator then
		local animator: Animator = foundAnimator
		local function load(animationId: string): AnimationTrack
			local track = Animations.Get(animator, animationId)
			table.insert(tracks, track)
			return track
		end

		local anims = AnimationConfig.FruitAnims
		local windUp = load(if left then anims.ChargeLeft else anims.ChargeRight)
		local held = load(if left then anims.LoopLeft else anims.LoopRight)
		-- The loop clips are shared with other charging effects, which loop them.
		held.Looped = true
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play(WIND_UP_FADE, 1, WIND_UP_SPEED)
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
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"

	local removeFire = addFire(character, left, fields[2] or "")
	local stopCharging = if isLocal then startCharging(character, left) else nil

	return function()
		if stopCharging then
			stopCharging()
		end
		if removeFire then
			removeFire()
		end
	end
end
