--!strict
--[[
	Gas fruit - Gastille, while the key is held.
	Status value: "<size scale * 100>|<fruit color string>".

	Everyone: a spinning ball of gas growing in front of the face.
	Template: ReplicatedStorage.Assets.Models.Fruits.Gas.Power4.ExplosionBall, a part with a
	"Mesh", two cross-shaped parts inside it ("ExplosionBall" and "ExplosionBall2", each
	with a "Mesh") and a "GasBreath" particle emitter.
	With s = size scale (melee level / cap * melee affinity, as the legacy script used):
	the ball's mesh grows 1.875 * s per second up to 7.5 * s, the arms of the cross grow
	6.25 * s per second up to 25 * s. It spins about 167 degrees per second.
	Colors: armament haki turns it dark; otherwise custom fruit colors paint it with the
	second color; otherwise the authored colors stay.

	Owner only: the breath charge animation (wind-up clip, then the held clip) and the
	character turned towards the mouse. The release animation, beam and explosion belong
	to the GasGastille one-shot effect.

	The legacy ball was a server part on a Motor6D, spun by a 0.03s server loop and
	scaled from a Heartbeat connection, with a recolor script cloned into it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local RENDER_STEP_NAME = "GasGastilleFacing"
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local FACE_OFFSET = CFrame.new(0, 0, -1)
-- 5 degrees every 0.03s in the legacy loop.
local SPIN_PER_SECOND = math.rad(5) / 0.03
local START_SCALE = 0.1
local BALL_GROWTH = 1.875
local BALL_MAX = 7.5
local CROSS_GROWTH = 6.25
local CROSS_MAX = 25
local CROSS_THICKNESS = 3

local function findMesh(part: Instance?): any
	local mesh = part and part:FindFirstChild("Mesh")
	return if mesh and mesh:IsA("DataModelMesh") then mesh else nil
end

-- Returns the cleanup of the ball, or nil when it could not be built.
local function addBall(character: Model, sizeScale: number, colors: string): (() -> ())?
	local head = character:FindFirstChild("Head")
	local template = EffectAssets.FindFruit("Gas", "Power4", "ExplosionBall")
	if not head or not head:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return nil
	end

	local ball = template:Clone()
	local parts: { BasePart } = { ball }
	for _, descendant in ball:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		elseif descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	-- The inner parts must follow the ball: weld them if the asset carries no joints.
	local hasJoints = ball:FindFirstChildWhichIsA("JointInstance", true) ~= nil
		or ball:FindFirstChildWhichIsA("WeldConstraint", true) ~= nil
	for _, part in parts do
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		if part ~= ball and not hasJoints then
			local joint = Instance.new("WeldConstraint")
			joint.Part0 = ball
			joint.Part1 = part
			joint.Parent = part
		end
	end

	local ballMesh = findMesh(ball)
	local crossMesh = findMesh(ball:FindFirstChild("ExplosionBall"))
	local crossMesh2 = findMesh(ball:FindFirstChild("ExplosionBall2"))
	local breath = ball:FindFirstChild("GasBreath")

	local authoredColors: { [BasePart]: Color3 } = {}
	for _, part in parts do
		authoredColors[part] = part.Color
	end
	local authoredBreath = if breath and breath:IsA("ParticleEmitter") then breath.Color else nil
	local _, secondary = FruitColor.Parse(colors)

	local function paint()
		local color = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_COLOR else secondary
		for _, part in parts do
			part.Color = color or authoredColors[part]
		end
		if breath and breath:IsA("ParticleEmitter") and authoredBreath then
			breath.Color = if color then ColorSequence.new(color) else authoredBreath
		end
	end
	paint()
	local hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

	local weld = Instance.new("Weld")
	weld.Name = "GasGastilleBall"
	weld.Part0 = head
	weld.Part1 = ball
	weld.C0 = FACE_OFFSET
	weld.Parent = ball
	ball.Parent = head

	local ballScale = START_SCALE
	local crossScale = START_SCALE
	local function applyScale()
		if ballMesh then
			ballMesh.Scale = Vector3.new(ballScale, ballScale, ballScale)
		end
		if crossMesh then
			crossMesh.Scale = Vector3.new(crossScale, CROSS_THICKNESS, CROSS_THICKNESS)
		end
		if crossMesh2 then
			crossMesh2.Scale = Vector3.new(CROSS_THICKNESS, crossScale, CROSS_THICKNESS)
		end
	end
	applyScale()

	local growConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
		weld.C1 *= CFrame.Angles(0, 0, SPIN_PER_SECOND * deltaTime)
		ballScale = math.min(ballScale + BALL_GROWTH * sizeScale * deltaTime, math.max(BALL_MAX * sizeScale, START_SCALE))
		crossScale = math.min(crossScale + CROSS_GROWTH * sizeScale * deltaTime, math.max(CROSS_MAX * sizeScale, START_SCALE))
		applyScale()
	end)

	return function()
		growConnection:Disconnect()
		hakiConnection:Disconnect()
		ball:Destroy()
	end
end

-- Returns the cleanup of the owner's animation and facing, or nil.
local function startCharging(character: Model): (() -> ())?
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

		local windUp = load(AnimationConfig.FruitAnims.BreathCharge)
		local held = load(AnimationConfig.FruitAnims.BreathCharged)
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
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local sizeScale = (tonumber(fields[1]) or 0) / 100

	local removeBall = addBall(character, sizeScale, fields[2] or "")
	local stopCharging = if isLocal then startCharging(character) else nil

	return function()
		if stopCharging then
			stopCharging()
		end
		if removeBall then
			removeBall()
		end
	end
end
