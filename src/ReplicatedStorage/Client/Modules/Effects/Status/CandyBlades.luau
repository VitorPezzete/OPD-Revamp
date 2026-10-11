--!strict
--[[
	Candy fruit - Syrup Blades: a candy blade on each arm while the status is active, plus
	(for the owner) the click that swings them.

	Status value: "<fruit slot>|<ability slot>|<fruit colors>".
	Templates: ReplicatedStorage.Assets.Models.Fruits.Candy.Power1.CandyBlade1 (right arm)
	and CandyBlade2 (left arm). Each is welded upside down to its arm and slides 1.883
	studs out of the hand over 1 s.

	First fruit color on both blades; dark while armament haki is on.

	Swinging: each click sends phase 3 of the ability; cooldown, hitbox and damage are
	decided by the server. The swing animation is played here and replicated by the
	Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local SWING_COOLDOWN = 0.25
-- The legacy swing: the clip played very fast and over-weighted.
local SWING_FADE = 0.2
local SWING_WEIGHT = 3
local SWING_SPEED = 12

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local EXTEND_TIME = 1
local ROTATION = CFrame.Angles(0, 0, math.rad(180))
local EXTENDED = CFrame.new(0, -1.883, 0) * ROTATION
local BLADES = {
	{ Arm = "Right Arm", Template = "CandyBlade1" },
	{ Arm = "Left Arm", Template = "CandyBlade2" },
}

local lastSwing = 0
local firstSwing = false

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary = FruitColor.Parse(fields[3] or "")

	local blades: { [BasePart]: Color3 } = {}
	local tracks: { [string]: AnimationTrack } = {}
	local hakiConnection: RBXScriptConnection? = nil
	local inputConnection: RBXScriptConnection? = nil

	for _, info in BLADES do
		local template = EffectAssets.FindFruit("Candy", "Power1", info.Template)
		local arm = character:FindFirstChild(info.Arm)
		if not template or not template:IsA("BasePart") or not arm or not arm:IsA("BasePart") then
			continue
		end

		local blade = template:Clone()
		for _, descendant in blade:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") then
				descendant:Destroy()
			end
		end
		blade.Anchored = false
		blade.CanCollide = false
		blade.CanQuery = false
		blade.CanTouch = false
		blade.Massless = true
		blade.CFrame = arm.CFrame * ROTATION

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = blade
		weld.C0 = ROTATION
		weld.Parent = blade

		blades[blade] = blade.Color
		blade.Parent = arm
		TweenService:Create(weld, TweenInfo.new(EXTEND_TIME, Enum.EasingStyle.Linear), { C0 = EXTENDED }):Play()
	end

	local function paint()
		local haki = character:GetAttribute(HAKI_ATTRIBUTE)
		for blade, authoredColor in blades do
			blade.Color = if haki then HAKI_COLOR elseif primary then primary else authoredColor
		end
	end

	if next(blades) ~= nil then
		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
	end

	if isLocal and fruitSlot and abilitySlot then
		local abilityService = Knit.GetService("AbilityService")

		local function playSwing(animationId: string)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if not animator then
				return
			end

			local track = Animations.Get(animator, animationId)
			tracks[animationId] = track
			track:Play(SWING_FADE, SWING_WEIGHT, SWING_SPEED)
		end

		inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
				-- The attack trigger of a gamepad.
				and input.KeyCode ~= Enum.KeyCode.ButtonR2
			then
				return
			end
			-- The blades stay on through a stun, but cannot be swung (the server refuses too).
			if character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled) or character:GetAttribute("Stunned") then
				return
			end

			local root = character.PrimaryPart
			local now = os.clock()
			if not root or now - lastSwing < SWING_COOLDOWN then
				return
			end
			lastSwing = now

			-- The aim point is unused by a swing; the root position always validates.
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, root.Position)

			firstSwing = not firstSwing
			local anims = AnimationConfig.Fruits.Candy
			playSwing(if firstSwing then anims.Anim2 else anims.Anim1)
		end)
	end

	return function()
		if inputConnection then
			inputConnection:Disconnect()
		end
		if hakiConnection then
			hakiConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop(0)
		end
		for blade in blades do
			blade:Destroy()
		end
	end
end
