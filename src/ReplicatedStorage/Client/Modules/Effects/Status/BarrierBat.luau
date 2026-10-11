--!strict
--[[
	Barrier fruit - Barrier Bat: the blade welded to the right arm while the status is
	active, plus (for the owner) the click that swings it.

	Status value: "<fruit slot>|<ability slot>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Barrier.Power5.BarrierBlade (a part);
	a plain bar when it is missing.

	A click sends the ability's secondary input (phase 3); cooldown, hitbox and damage
	are decided by the server. The swing animation is played here and replicated by the
	Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local SWING_COOLDOWN = 0.25
-- The legacy swing: the dagger clips played very fast and over-weighted.
local SWING_SPEED = 16
local SWING_WEIGHT = 3
local SWING_FADE = 0.1

local HAKI_ATTRIBUTE = "Haki"
local STUN_ATTRIBUTE = "Stunned"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local DEFAULT_COLOR = Color3.fromRGB(170, 170, 220)

local ARM_NAME = "Right Arm"
local WELD_C0 = CFrame.new(0, -1, -1.7) * CFrame.Angles(math.rad(90), 0, math.rad(90))
local FALLBACK_SIZE = Vector3.new(0.5, 0.5, 4.5)

local lastSwing = 0
-- The legacy swings started with Dagger2.
local swingFirst = true

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary = EffectAssets.Colors(fields[3], DEFAULT_COLOR, DEFAULT_COLOR)

	local blade: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil
	local inputConnection: RBXScriptConnection? = nil
	local tracks: { [string]: AnimationTrack } = {}

	local arm = character:FindFirstChild(ARM_NAME)
	if arm and arm:IsA("BasePart") then
		local template = EffectAssets.FindFruit("Barrier", "Power5", "BarrierBlade")
		local part: BasePart
		if template and template:IsA("BasePart") then
			part = template:Clone()
		else
			local bar = Instance.new("Part")
			bar.Size = FALLBACK_SIZE
			bar.Material = Enum.Material.Plastic
			bar.Transparency = 0.24
			part = bar
		end
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = part
		weld.C0 = WELD_C0
		weld.Parent = part

		local function paint()
			part.Color = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_COLOR else primary
		end

		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
		part.Parent = arm
		blade = part
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
			-- Sealed (which covers Barrier Body) or stunned: the server refuses the swing too.
			if
				character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled)
				or character:GetAttribute(STUN_ATTRIBUTE)
			then
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
		if blade then
			blade:Destroy()
		end
	end
end
