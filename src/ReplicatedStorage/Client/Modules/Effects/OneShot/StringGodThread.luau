--!strict
--[[
	String fruit - God Thread, released: the sixteen gathered threads are driven forward
	as one lance. Their tips meet in a point that leaves the user and reaches the full
	range in 0.5 s (the legacy tween of the threads' far end); everything is removed
	after 1.25 s. The damage is instant on the server; this is only the picture.

	params: { Direction: Vector3, Range: number, Haki: boolean, Held: number (seconds the
	          charge was held), Hand: "Right" | "Left", Colors: string, Caster: Model }

	Each thread is the Beam of ReplicatedStorage.Assets.Models.Fruits.String.Power6.Finger,
	from the moving point to one of five attachments one stud behind the caster's root,
	rolled so the threads bulge in different planes, as wide at the caster as the charge
	had made them (1 to 10 studs over 12 s for eight of them, 20 s for the others).
	Without the template plain beams are used.

	The caster's own client also turns the character towards the shot and snaps the wave
	animation of the hand, at 32 times the clip's speed as in the legacy game.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

-- Roll of the base attachment (degrees), bend, seconds of charge to full width.
type Thread = { Roll: number, Curve: number, GrowTime: number }

local THREADS: { Thread } = {
	{ Roll = 0, Curve = -20, GrowTime = 12 },
	{ Roll = 0, Curve = -20, GrowTime = 12 },
	{ Roll = 0, Curve = -20, GrowTime = 12 },
	{ Roll = 0, Curve = -20, GrowTime = 12 },
	{ Roll = 0, Curve = 20, GrowTime = 12 },
	{ Roll = 0, Curve = 20, GrowTime = 12 },
	{ Roll = 0, Curve = 20, GrowTime = 12 },
	{ Roll = 0, Curve = 20, GrowTime = 12 },
	{ Roll = 90, Curve = -20, GrowTime = 20 },
	{ Roll = 45, Curve = -20, GrowTime = 20 },
	{ Roll = 0, Curve = -20, GrowTime = 20 },
	{ Roll = -45, Curve = -20, GrowTime = 20 },
	{ Roll = 90, Curve = 20, GrowTime = 20 },
	{ Roll = 45, Curve = 20, GrowTime = 20 },
	{ Roll = 0, Curve = 20, GrowTime = 20 },
	{ Roll = -45, Curve = 20, GrowTime = 20 },
}
local BASE_OFFSET = Vector3.new(0, 0, 1)
local EXTEND_TIME = 0.5
local LIFETIME = 1.25
local START_WIDTH = 1
local FULL_WIDTH = 10
local WAVE_FADE = 0.1
local WAVE_SPEED = 32
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local function point(position: CFrame): BasePart
	local part = Instance.new("Part")
	part.Name = "StringGodThread"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.CFrame = position
	part.Parent = World.Effects()
	Debris:AddItem(part, LIFETIME)
	return part
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end

	local direction = params.Direction
	local range = params.Range
	if typeof(direction) ~= "Vector3" or type(range) ~= "number" or direction.Magnitude < 1e-3 or range <= 0 then
		return
	end

	local color = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "") or DEFAULT_COLOR
	if params.Haki == true then
		color = HAKI_COLOR
	end
	local held: number = if type(params.Held) == "number" then params.Held else 0

	local unit = direction.Unit
	local up = if math.abs(unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local facing = CFrame.lookAt(origin, origin + unit, up)

	local caster = params.Caster
	local casterRoot: BasePart? = nil
	if typeof(caster) == "Instance" and caster:IsA("Model") then
		local found = caster:FindFirstChild("HumanoidRootPart")
		if found and found:IsA("BasePart") then
			casterRoot = found
		end

		if caster == Players.LocalPlayer.Character then
			local humanoid = caster:FindFirstChildOfClass("Humanoid")
			local flat = Vector3.new(unit.X, 0, unit.Z)
			if casterRoot and humanoid and not humanoid.Sit and flat.Magnitude > 0.05 then
				casterRoot.CFrame = CFrame.lookAt(casterRoot.Position, casterRoot.Position + flat)
			end
			local animator = Animations.FindAnimator(caster)
			if animator then
				local anims = AnimationConfig.FruitAnims
				Animations.Play(
					animator,
					if params.Hand == "Left" then anims.WaveLeft else anims.WaveRight,
					WAVE_FADE,
					1,
					WAVE_SPEED
				)
			end
		end
	end

	-- The threads start behind the caster and follow it; without it, where it stood.
	local holder: BasePart = casterRoot or point(facing)
	local bases: { [number]: Attachment } = {}
	local function getBase(roll: number): Attachment
		local base = bases[roll]
		if not base then
			base = Instance.new("Attachment")
			base.Name = "StringGodThreadBase"
			base.CFrame = CFrame.new(BASE_OFFSET) * CFrame.Angles(0, 0, math.rad(roll))
			base.Parent = holder
			bases[roll] = base
			Debris:AddItem(base, LIFETIME)
		end
		return base
	end

	local head = point(facing)
	local tip = Instance.new("Attachment")
	tip.Parent = head

	local finger = EffectAssets.FindFruit("String", "Power6", "Finger")
	local beamTemplate = finger and finger:FindFirstChildOfClass("Beam")
	for _, thread in THREADS do
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
		beam.Width1 = START_WIDTH + (FULL_WIDTH - START_WIDTH) * math.clamp(held / thread.GrowTime, 0, 1)
		beam.Color = ColorSequence.new(color)
		beam.Parent = head
	end

	TweenService:Create(head, TweenInfo.new(EXTEND_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = facing * CFrame.new(0, 0, -range),
	}):Play()
end
