--!strict
--[[
	Light fruit - Light Sword: the blade of light on the right arm while the status is
	active, plus (for the owner) the click that swings it.

	Status value: "<fruit slot>;<ability slot>;<fruit colors>".
	Templates: ReplicatedStorage.Assets.Models.Fruits.Light.Power1.LightSword (a union
	with a Trail), LightSpike (used twice, crossed) and LightGuard, welded to the arm
	with the legacy offsets. All take the first fruit color (the blade's own color by
	default) and turn dark while armament haki is on.

	A click sends a phase 3 input for the Light Sword ability; cooldown, hitbox and
	damage are decided by the server. The swing animation is played here and replicated
	by the Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local SWING_COOLDOWN = 0.4
-- The legacy swing: the dagger clips played very fast and over-weighted.
local SWING_SPEED = 16
local SWING_WEIGHT = 3
local SWING_FADE = 0.1

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local ARM_NAME = "Right Arm"
-- Template name and legacy Weld.C0 (Part0 = arm) of each piece.
local PIECES: { { Name: string, Offset: CFrame } } = {
	{ Name = "LightSword", Offset = CFrame.new(0, -1, -3.725) * CFrame.Angles(math.rad(90), 0, 0) },
	{ Name = "LightSpike", Offset = CFrame.new(0, -1, -0.6) * CFrame.Angles(0, 0, math.rad(90)) },
	{ Name = "LightSpike", Offset = CFrame.new(0, -1, -0.6) * CFrame.Angles(0, math.rad(90), 0) },
	{ Name = "LightGuard", Offset = CFrame.new(0, -1, -0.6) * CFrame.Angles(0, math.rad(90), 0) },
}

local lastSwing = 0
local swingFirst = false

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local parts: { BasePart } = {}
	local hakiConnection: RBXScriptConnection? = nil
	local inputConnection: RBXScriptConnection? = nil
	local tracks: { [string]: AnimationTrack } = {}

	local arm = character:FindFirstChild(ARM_NAME)
	if arm and arm:IsA("BasePart") then
		local trail: Trail? = nil
		local authoredTrail: ColorSequence? = nil
		local authoredColor: Color3? = nil

		for _, piece in PIECES do
			local template = EffectAssets.FindFruit("Light", "Power1", piece.Name)
			if not template or not template:IsA("BasePart") then
				continue
			end

			local part = template:Clone()
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CFrame = arm.CFrame * piece.Offset

			local weld = Instance.new("Weld")
			weld.Part0 = arm
			weld.Part1 = part
			weld.C0 = piece.Offset
			weld.Parent = part

			if piece.Name == "LightSword" then
				authoredColor = part.Color
				trail = part:FindFirstChildOfClass("Trail")
				authoredTrail = if trail then trail.Color else nil
			end
			table.insert(parts, part)
		end

		local function paint()
			local haki = character:GetAttribute(HAKI_ATTRIBUTE)
			local color = if haki then HAKI_COLOR else primary or authoredColor
			for _, part in parts do
				if color then
					part.Color = color
				end
			end
			if trail then
				if haki then
					trail.Color = ColorSequence.new(HAKI_COLOR)
				elseif primary and secondary then
					trail.Color = FruitColor.ToSequence(primary, secondary)
				elseif authoredTrail then
					trail.Color = authoredTrail
				end
			end
		end

		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
		for _, part in parts do
			part.Parent = arm
		end
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
			if character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled) then
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

			swingFirst = not swingFirst
			playSwing(if swingFirst then AnimationConfig.Dagger1 else AnimationConfig.Dagger2)
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
		for _, part in parts do
			part:Destroy()
		end
	end
end
