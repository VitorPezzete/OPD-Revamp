--!strict
--[[
	Snow fruit - Snow Pellet, while the key is held: a snowball growing in the hand.
	Status value: "<Right|Left>|<sniper affinity>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Snow.Power3.Snow3 (a part with a
	"Mesh" and a "SnowTrigger" emitter). Over 3 s its mesh grows from nothing to
	13 * affinity and it slides 0.5 * affinity studs down the arm.

	First fruit color on the ball, both on the emitter; dark while armament haki is on.
	Owner only: the charge animation (wind-up clip at 4 times its speed, then the held
	clip).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_TIME = 3
local START_SCALE = Vector3.new(0.001, 0.001, 0.001)
local SCALE_PER_AFFINITY = 13
local SLIDE_PER_AFFINITY = 0.5
local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local WIND_UP_SPEED = 4

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"
	local affinity = tonumber(fields[2]) or 1
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local snowball: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil

	local template = EffectAssets.FindFruit("Snow", "Power3", "Snow3")
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
		ball.CFrame = arm.CFrame

		-- The template's own "ManualWeld" holds the ball on the arm (the legacy server only
		-- filled in its Part0 and reset its C0); its C1 is part of where the ball sits.
		local found = ball:FindFirstChild("ManualWeld")
		local weld: JointInstance
		if found and found:IsA("JointInstance") then
			weld = found
			if not weld.Part1 then
				weld.Part1 = ball
			end
		else
			local created = Instance.new("Weld")
			created.Part1 = ball
			created.Parent = ball
			weld = created
		end
		weld.Part0 = arm
		weld.C0 = CFrame.new()

		local emitter = ball:FindFirstChild("SnowTrigger", true)
		local authoredColor = ball.Color
		local authoredSequence = if emitter and emitter:IsA("ParticleEmitter") then emitter.Color else nil

		local function paint()
			local color = authoredColor
			local sequence = authoredSequence
			if character:GetAttribute(HAKI_ATTRIBUTE) then
				color, sequence = HAKI_COLOR, ColorSequence.new(HAKI_COLOR)
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

		local tweenInfo = TweenInfo.new(GROW_TIME)
		local mesh = ball:FindFirstChildWhichIsA("DataModelMesh")
		if mesh then
			local scale = SCALE_PER_AFFINITY * affinity
			mesh.Scale = START_SCALE
			TweenService:Create(mesh, tweenInfo, { Scale = Vector3.new(scale, scale, scale) }):Play()
		end
		TweenService:Create(weld, tweenInfo, { C0 = CFrame.new(0, -SLIDE_PER_AFFINITY * affinity, 0) }):Play()

		ball.Parent = arm
		snowball = ball
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
		windUp:Play(0.1, 1, WIND_UP_SPEED)
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
		if snowball then
			snowball:Destroy()
		end
	end
end
