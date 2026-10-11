--!strict
--[[
	String fruit - God Thread while charging: sixteen threads fan out in front of the
	user from a point at its back and thicken as the charge builds (from 1 to 10 studs
	over 12 s for the outer ring, 20 s for the inner one). The owner's character also
	faces the aim point.

	Status value: "<haki 0/1>|<fruit colors>|<Right|Left>".

	Each thread is the Beam of ReplicatedStorage.Assets.Models.Fruits.String.Power6.Finger
	(the string texture), from a tip held at its legacy offset from the torso to one of
	five attachments one stud behind the root, rolled differently so the threads bend in
	different planes. The legacy tips were physical parts pulled into place by
	AlignPosition; here they slide out from the body in a third of a second. Without the
	template plain beams are used.

	White, the first fruit color, or dark when the charge started with armament haki on.
	Owner only: the charge animation (wind-up clip, then the held clip).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

-- Tip offset from the torso, roll of its base attachment (degrees), bend, seconds to full width.
type Thread = { Tip: Vector3, Roll: number, Curve: number, GrowTime: number }

local THREADS: { Thread } = {
	{ Tip = Vector3.new(7.5, 12.99, -15), Roll = 0, Curve = -20, GrowTime = 12 },
	{ Tip = Vector3.new(12.99, 7.5, -15), Roll = 0, Curve = -20, GrowTime = 12 },
	{ Tip = Vector3.new(12.99, -7.5, -15), Roll = 0, Curve = -20, GrowTime = 12 },
	{ Tip = Vector3.new(7.5, -12.99, -15), Roll = 0, Curve = -20, GrowTime = 12 },
	{ Tip = Vector3.new(-7.5, -12.99, -15), Roll = 0, Curve = 20, GrowTime = 12 },
	{ Tip = Vector3.new(-12.99, -7.5, -15), Roll = 0, Curve = 20, GrowTime = 12 },
	{ Tip = Vector3.new(-12.99, 7.5, -15), Roll = 0, Curve = 20, GrowTime = 12 },
	{ Tip = Vector3.new(-7.5, 12.99, -15), Roll = 0, Curve = 20, GrowTime = 12 },
	{ Tip = Vector3.new(0, 7.5, -7.5), Roll = 90, Curve = -20, GrowTime = 20 },
	{ Tip = Vector3.new(5.303, 5.303, -7.5), Roll = 45, Curve = -20, GrowTime = 20 },
	{ Tip = Vector3.new(7.5, 0, -7.5), Roll = 0, Curve = -20, GrowTime = 20 },
	{ Tip = Vector3.new(5.303, -5.303, -7.5), Roll = -45, Curve = -20, GrowTime = 20 },
	{ Tip = Vector3.new(0, -7.5, -7.5), Roll = 90, Curve = 20, GrowTime = 20 },
	{ Tip = Vector3.new(-5.303, -5.303, -7.5), Roll = 45, Curve = 20, GrowTime = 20 },
	{ Tip = Vector3.new(-7.5, 0, -7.5), Roll = 0, Curve = 20, GrowTime = 20 },
	{ Tip = Vector3.new(-5.303, 5.303, -7.5), Roll = -45, Curve = 20, GrowTime = 20 },
}
local BASE_OFFSET = Vector3.new(0, 0, 1)
local FAN_TIME = 0.35
local START_WIDTH = 1
local FULL_WIDTH = 10
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local root = character.PrimaryPart
	if not root then
		return noop
	end
	local foundTorso = character:FindFirstChild("Torso")
	local torso: BasePart = if foundTorso and foundTorso:IsA("BasePart") then foundTorso else root

	local fields = EffectAssets.Unpack(value)
	local color = FruitColor.Parse(fields[2] or "") or DEFAULT_COLOR
	if fields[1] == "1" then
		color = HAKI_COLOR
	end
	local left = fields[3] == "Left"

	local finger = EffectAssets.FindFruit("String", "Power6", "Finger")
	local beamTemplate = finger and finger:FindFirstChildOfClass("Beam")

	local created: { Instance } = {}
	local bases: { [number]: Attachment } = {}
	local function getBase(roll: number): Attachment
		local base = bases[roll]
		if not base then
			base = Instance.new("Attachment")
			base.Name = "StringGodThreadBase"
			base.CFrame = CFrame.new(BASE_OFFSET) * CFrame.Angles(0, 0, math.rad(roll))
			base.Parent = root
			bases[roll] = base
			table.insert(created, base)
		end
		return base
	end

	for _, thread in THREADS do
		local tip = Instance.new("Attachment")
		tip.Name = "StringGodThreadTip"
		tip.Parent = torso
		table.insert(created, tip)
		TweenService:Create(tip, TweenInfo.new(FAN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = thread.Tip,
		}):Play()

		local beam: Beam
		if beamTemplate then
			beam = beamTemplate:Clone()
		else
			local plain = Instance.new("Beam")
			plain.Width0 = 0
			plain.FaceCamera = true
			plain.Segments = 33
			beam = plain
		end
		beam.Attachment0 = tip
		beam.Attachment1 = getBase(thread.Roll)
		beam.CurveSize1 = thread.Curve
		beam.Width1 = START_WIDTH
		beam.Color = ColorSequence.new(color)
		beam.Parent = tip

		TweenService:Create(beam, TweenInfo.new(thread.GrowTime, Enum.EasingStyle.Linear), { Width1 = FULL_WIDTH }):Play()
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil
	local connection: RBXScriptConnection? = nil
	if isLocal then
		local inputController = Knit.GetController("InputController")
		connection = RunService.RenderStepped:Connect(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Sit then
				return
			end

			local aim: Vector3 = inputController:GetAimPosition()
			local target = Vector3.new(aim.X, root.Position.Y, aim.Z)
			if (target - root.Position).Magnitude > 0.5 then
				root.CFrame = CFrame.lookAt(root.Position, target)
			end
		end)

		local animator = Animations.FindAnimator(character)
		if animator then
			local anims = AnimationConfig.FruitAnims
			local windUp = Animations.Get(animator, if left then anims.WaveLeftCharge else anims.WaveRightCharge)
			local held = Animations.Get(animator, if left then anims.WaveLeftCharged else anims.WaveRightCharged)
			table.insert(tracks, windUp)
			table.insert(tracks, held)
			stoppedConnection = windUp.Stopped:Connect(function()
				if active then
					held:Play()
				end
			end)
			windUp:Play()
		end
	end

	return function()
		active = false
		if connection then
			connection:Disconnect()
		end
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		for _, instance in created do
			instance:Destroy()
		end
	end
end
