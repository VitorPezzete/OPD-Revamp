--!strict
--[[
	Bomb fruit - a charge being held (all four abilities).
	Status value:
	"<kind>|<max sphere size>|<seconds to reach it>|<fruit colors>|<hand>|<affinity>".

	A sphere swells on each charging limb, welded one stud below its centre:
		Punch, Wave  the arm of <hand>     Boost  both legs     Full  arms and legs
	Template: ReplicatedStorage.Assets.Models.Fruits.Bomb.Hand.ExplosionBall (a part with
	a mesh). As in the legacy game the MESH scale goes from 0.1 to the max size, and the
	sphere is removed 0.15 s after the charge ends.

	Colors: first fruit color (second for Full Body); without custom colors the color of
	Bomb.Power5.ExplosionBall (Power6 for Full Body). Dark while armament haki is on,
	except for Full Body.

	Full Body also pulses, as the legacy rings did: starting 0.25 s in, once a second, a
	sphere on the root collapses from a mesh scale of 300 * level scale * affinity * size
	to nothing. `size` starts at 5 * affinity and loses 0.2 * affinity per pulse; the
	collapse takes 1.11 s for the first pulse and 0.09 s less for each next one, down to
	0.3 s. (300 * level scale * affinity is 24 times the limb sphere's max size.)

	Owner only: the charge animation, a wind-up clip followed by a held clip (Punch1*
	at four times the speed for Punch, Wave* for Wave, FullCharge10s / FullCharged for
	Full Body; Boost has none). It replicates through the Animator.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local START_SCALE = Vector3.new(0.1, 0.1, 0.1)
local WELD_OFFSET = CFrame.new(0, -1, 0)
local LINGER = 0.15
local PUNCH_WIND_UP_SPEED = 4

local PULSE_START_DELAY = 0.25
local PULSE_INTERVAL = 1
local PULSE_FIRST_DURATION = 1.2
local PULSE_MIN_DURATION = 0.3
local PULSE_DURATION_STEP = 0.09
-- Pulse mesh scale = PULSE_SCALE * limb sphere max size * size.
local PULSE_SCALE = 24
local PULSE_FIRST_SIZE = 5
local PULSE_SIZE_STEP = 0.2

local function noop() end

local function limbsOf(kind: string, hand: string): { string }?
	if kind == "Punch" or kind == "Wave" then
		return { hand .. " Arm" }
	elseif kind == "Boost" then
		return { "Right Leg", "Left Leg" }
	elseif kind == "Full" then
		return { "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
	end
	return nil
end

-- Wind-up clip, held clip and wind-up speed of a charge, if it has an animation.
local function clipsOf(kind: string, left: boolean): (string?, string?, number)
	local anims = AnimationConfig.FruitAnims
	if kind == "Punch" then
		return if left then anims.Punch1LeftCharge else anims.Punch1RightCharge,
			if left then anims.Punch1LeftCharged else anims.Punch1RightCharged,
			PUNCH_WIND_UP_SPEED
	elseif kind == "Wave" then
		return if left then anims.WaveLeftCharge else anims.WaveRightCharge,
			if left then anims.WaveLeftCharged else anims.WaveRightCharged,
			1
	elseif kind == "Full" then
		return anims.FullCharge10s, anims.FullCharged, 1
	end
	return nil, nil, 1
end

local function prepare(template: BasePart): (BasePart, DataModelMesh?)
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
	ball.CastShadow = false
	return ball, ball:FindFirstChildWhichIsA("DataModelMesh")
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local kind = fields[1] or "Punch"
	local maxSize = math.max(tonumber(fields[2]) or 1, 0.1)
	local seconds = math.max(tonumber(fields[3]) or 3, 0.1)
	local hand = if fields[5] == "Left" then "Left" else "Right"
	local affinity = math.max(tonumber(fields[6]) or 1, 0.1)
	local isFull = kind == "Full"

	local limbNames = limbsOf(kind, hand)
	if not limbNames then
		return noop
	end

	local active = true
	local balls: { BasePart } = {}
	local pulses: { [BasePart]: boolean } = {}
	local hakiConnection: RBXScriptConnection? = nil

	local template = EffectAssets.FindFruit("Bomb", "Hand", "ExplosionBall")
	if template and template:IsA("BasePart") then
		local ballTemplate: BasePart = template
		local colorSource = EffectAssets.FindFruit("Bomb", if isFull then "Power6" else "Power5", "ExplosionBall")
		local authored = if colorSource and colorSource:IsA("BasePart") then colorSource.Color else ballTemplate.Color
		local primary, secondary = EffectAssets.Colors(fields[4], authored, authored)
		local baseColor = if isFull then secondary else primary
		local targetScale = Vector3.new(maxSize, maxSize, maxSize)

		for _, limbName in limbNames do
			local limb = character:FindFirstChild(limbName)
			if not limb or not limb:IsA("BasePart") then
				continue
			end

			local ball, mesh = prepare(ballTemplate)
			ball.CFrame = limb.CFrame * WELD_OFFSET

			local weld = Instance.new("Weld")
			weld.Part0 = limb
			weld.Part1 = ball
			weld.C0 = WELD_OFFSET
			weld.Parent = ball

			local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear)
			if mesh then
				mesh.Scale = START_SCALE
				TweenService:Create(mesh, info, { Scale = targetScale }):Play()
			else
				ball.Size = START_SCALE
				TweenService:Create(ball, info, { Size = targetScale }):Play()
			end

			ball.Parent = limb
			table.insert(balls, ball)
		end

		local function paint()
			local hakiOn = not isFull and character:GetAttribute(HAKI_ATTRIBUTE) ~= nil
			for _, ball in balls do
				ball.Color = if hakiOn then HAKI_COLOR else baseColor
			end
		end
		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

		local root = character:FindFirstChild("HumanoidRootPart")
		if isFull and root and root:IsA("BasePart") then
			local rootPart: BasePart = root
			task.spawn(function()
				task.wait(PULSE_START_DELAY)
				local duration = PULSE_FIRST_DURATION
				local size = PULSE_FIRST_SIZE * affinity
				local step = PULSE_SIZE_STEP * affinity
				-- Stops by itself once the pulses have shrunk away, like the legacy rings.
				while active and size > step and rootPart.Parent do
					local startSize = PULSE_SCALE * maxSize * size
					size -= step
					if duration > PULSE_MIN_DURATION then
						duration -= PULSE_DURATION_STEP
					end

					local pulse, mesh = prepare(ballTemplate)
					pulse.Color = baseColor
					pulse.CFrame = rootPart.CFrame * WELD_OFFSET

					local weld = Instance.new("Weld")
					weld.Part0 = rootPart
					weld.Part1 = pulse
					weld.C0 = WELD_OFFSET
					weld.Parent = pulse

					local startScale = Vector3.new(startSize, startSize, startSize)
					local info = TweenInfo.new(duration, Enum.EasingStyle.Linear)
					if mesh then
						mesh.Scale = startScale
						TweenService:Create(mesh, info, { Scale = START_SCALE }):Play()
					else
						pulse.Size = startScale
						TweenService:Create(pulse, info, { Size = START_SCALE }):Play()
					end
					pulse.Parent = rootPart
					pulses[pulse] = true

					task.wait(PULSE_INTERVAL)
					pulses[pulse] = nil
					pulse:Destroy()
				end
			end)
		end
	end

	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local windUpId, heldId, windUpSpeed = clipsOf(kind, hand == "Left")
	if isLocal and animator and windUpId and heldId then
		local windUp = Animations.Get(animator, windUpId)
		local held = Animations.Get(animator, heldId)
		table.insert(tracks, windUp)
		table.insert(tracks, held)
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play(0.1, 1, windUpSpeed)
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
		for _, ball in balls do
			Debris:AddItem(ball, LINGER)
		end
		for pulse in pulses do
			pulse:Destroy()
		end
		table.clear(pulses)
	end
end
