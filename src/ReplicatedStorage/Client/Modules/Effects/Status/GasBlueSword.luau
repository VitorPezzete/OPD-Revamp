--!strict
--[[
	Gas fruit - Blue Sword: the blade welded to the right arm while the status is
	active, plus (for the owner) the click that swings it.

	Status value: "<fruit slot>|<ability slot>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Gas.Power2.GasBlueSword (a union whose
	"GasBlueSwordBit" child carries the "Outter" and "Inner" flames).

	Colors: custom fruit colors paint the outer flame with the first and the inner one
	with the second; armament haki turns them dark (outer) and black (inner) for as long
	as it is on. Otherwise the authored colors stay.

	Swinging: a click sends the ability's secondary input (phase 3); cooldown, hitbox and
	damage are all decided by the server. The swing animation is played here and
	replicated by the Animator.
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
local SWING_COOLDOWN = 0.3
-- The legacy swing: the dagger clips played very fast and over-weighted.
local SWING_SPEED = 16
local SWING_WEIGHT = 3
local SWING_FADE = 0.1

local HAKI_ATTRIBUTE = "Haki"
local HAKI_OUTER = Color3.fromRGB(25, 12, 25)
local HAKI_INNER = Color3.fromRGB(0, 0, 0)
local HAKI_OUTER_EMISSION = 0.5
local HAKI_INNER_EMISSION = 0
local NORMAL_EMISSION = 0.8

local ARM_NAME = "Right Arm"
local WELD_C0 = CFrame.new(0, -1, 0.15) * CFrame.Angles(math.rad(-90), math.rad(90), math.rad(90))

local lastSwing = 0
local swingFirst = false

-- "Outter" / "Inner" are particle emitters, beams or trails: all three have these.
local function isFlame(instance: Instance?): boolean
	return instance ~= nil
		and (instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail"))
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local sword: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil
	local inputConnection: RBXScriptConnection? = nil
	local tracks: { [string]: AnimationTrack } = {}

	local template = EffectAssets.FindFruit("Gas", "Power2", "GasBlueSword")
	local arm = character:FindFirstChild(ARM_NAME)
	if template and template:IsA("BasePart") and arm and arm:IsA("BasePart") then
		local blade = template:Clone()
		blade.Anchored = false
		blade.CanCollide = false
		blade.CanQuery = false
		blade.CanTouch = false
		blade.Massless = true

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = blade
		weld.C0 = WELD_C0
		weld.Parent = blade

		local foundOuter = blade:FindFirstChild("Outter", true)
		local foundInner = blade:FindFirstChild("Inner", true)
		local outer: any = if isFlame(foundOuter) then foundOuter else nil
		local inner: any = if isFlame(foundInner) then foundInner else nil
		local authoredOuter = outer and outer.Color
		local authoredInner = inner and inner.Color

		local function paint()
			local haki = character:GetAttribute(HAKI_ATTRIBUTE)
			if outer then
				outer.Color = if haki
					then ColorSequence.new(HAKI_OUTER)
					elseif primary then ColorSequence.new(primary)
					else authoredOuter
				outer.LightEmission = if haki then HAKI_OUTER_EMISSION else NORMAL_EMISSION
			end
			if inner then
				inner.Color = if haki
					then ColorSequence.new(HAKI_INNER)
					elseif secondary then ColorSequence.new(secondary)
					else authoredInner
				inner.LightEmission = if haki then HAKI_INNER_EMISSION else NORMAL_EMISSION
			end
		end

		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
		blade.Parent = arm
		sword = blade
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
		if sword then
			sword:Destroy()
		end
	end
end
