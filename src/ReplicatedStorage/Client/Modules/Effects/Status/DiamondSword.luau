--!strict
--[[
	Diamond fruit - Diamond Blade: the blade welded to the right arm while the status is
	active, plus (for the owner) the click that swings it.

	Status value: "<fruit slot>;<ability slot>;<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Diamond.Power1.DiamondSword (a part with a Trail).

	Swinging: the ability framework only carries "pressed" / "released" per ability, so a
	click sends a *release* of the Diamond Blade ability, which the server treats as a
	swing (cooldown, hitbox and damage are all decided there). The swing animation is
	played here and replicated by the Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)

local PHASE_END = 2
local SWING_COOLDOWN = 0.5
-- The legacy swing: the dagger clips played very fast and over-weighted.
local SWING_SPEED = 16
local SWING_WEIGHT = 3
local SWING_FADE = 0.1

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local ARM_NAME = "Right Arm"
local WELD_C0 = CFrame.Angles(0, math.rad(180), math.rad(90))
local WELD_C1 = CFrame.new(1, 0, -1.8)

local lastSwing = 0
local swingFirst = false

local function findTemplate(): BasePart?
	local models = ReplicatedStorage.Assets:FindFirstChild("Models")
	local fruits = models and models:FindFirstChild("Fruits")
	local fruit = fruits and fruits:FindFirstChild("Diamond")
	local folder = fruit and fruit:FindFirstChild("Power1")
	local template = folder and folder:FindFirstChild("DiamondSword")
	return if template and template:IsA("BasePart") then template else nil
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local sword: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil
	local inputConnection: RBXScriptConnection? = nil
	local tracks: { [string]: AnimationTrack } = {}

	local template = findTemplate()
	local arm = character:FindFirstChild(ARM_NAME)
	if template and arm and arm:IsA("BasePart") then
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
		weld.C1 = WELD_C1
		weld.Parent = blade

		local trail = blade:FindFirstChildOfClass("Trail")
		local authoredColor = blade.Color
		local authoredTrail = trail and trail.Color

		local function paint()
			if character:GetAttribute(HAKI_ATTRIBUTE) then
				blade.Color = HAKI_COLOR
				if trail then
					trail.Color = ColorSequence.new(HAKI_COLOR)
				end
			elseif primary and secondary then
				blade.Color = primary
				if trail then
					trail.Color = FruitColor.ToSequence(primary, secondary)
				end
			else
				blade.Color = authoredColor
				if trail and authoredTrail then
					trail.Color = authoredTrail
				end
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
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_END, root.Position)

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
