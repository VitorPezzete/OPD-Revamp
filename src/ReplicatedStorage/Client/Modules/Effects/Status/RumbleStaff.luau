--!strict
--[[
	Rumble fruit - Rumble Staff: the staff welded to the right arm while the status is
	active, plus (for the owner) the click that swings it.

	Status value: "<fruit slot>;<ability slot>;<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Rumble.Power1.RumbleStaff (a MeshPart
	with a child "MeshPart"). The shaft takes the first fruit color and the child the
	second; both go dark while armament haki is on.

	A click sends a phase 3 input for the Rumble Staff ability; cooldown, hitbox and
	damage are decided by the server. The three swing animations play in turn, very fast
	and over-weighted as in the legacy game, and are replicated by the Animator. The
	swing sound and the spin of the staff on every third swing are drawn by
	Effects.OneShot.RumbleStaffSwing: at once here for the owner, from the server's
	announcement of the swing for everyone else.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawSwing = require(script.Parent.Parent.OneShot.RumbleStaffSwing)

local PHASE_ACTION = 3
local SWING_COOLDOWN = 0.25
local SWING_SPEED = 16
local SWING_WEIGHT = 3
local SWING_FADE = 0.1

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = Color3.fromRGB(25, 12, 25)

local ARM_NAME = "Right Arm"
-- Legacy weld, staff -> arm: staff.CFrame * STAFF_TO_ARM = arm.CFrame.
local STAFF_TO_ARM = CFrame.new(-0.8, 0, 0) * CFrame.Angles(math.rad(90), 0, math.rad(90))

local lastSwing = 0
local swingIndex = 0

local function getSwingAnimations(): { string }
	local fruits = (AnimationConfig :: any).Fruits
	local rumble = fruits and fruits.Rumble
	if not rumble then
		return {}
	end
	return { rumble.Anim1, rumble.Anim2, rumble.Anim3 }
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local staff: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil
	local inputConnection: RBXScriptConnection? = nil
	local tracks: { [string]: AnimationTrack } = {}

	local template = EffectAssets.FindFruit("Rumble", "Power1", "RumbleStaff")
	local arm = character:FindFirstChild(ARM_NAME)
	if template and template:IsA("BasePart") and arm and arm:IsA("BasePart") then
		local shaft = template:Clone()
		local head = shaft:FindFirstChild("MeshPart")
		for _, part in { shaft, head } do
			if part and part:IsA("BasePart") then
				part.Anchored = false
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Massless = true
			end
		end
		shaft.CFrame = arm.CFrame * STAFF_TO_ARM:Inverse()

		local weld = Instance.new("Weld")
		weld.Name = "Grip"
		weld.Part0 = arm
		weld.Part1 = shaft
		weld.C0 = STAFF_TO_ARM:Inverse()
		weld.Parent = shaft

		local authoredShaft = shaft.Color
		local authoredHead = if head and head:IsA("BasePart") then head.Color else authoredShaft

		local function paint()
			local shaftColor, headColor = authoredShaft, authoredHead
			if character:GetAttribute(HAKI_ATTRIBUTE) then
				shaftColor, headColor = HAKI_COLOR, HAKI_COLOR
			elseif primary and secondary then
				shaftColor, headColor = primary, secondary
			end
			shaft.Color = shaftColor
			if head and head:IsA("BasePart") then
				head.Color = headColor
			end
		end

		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)
		shaft.Parent = arm
		staff = shaft
	end

	if isLocal and fruitSlot and abilitySlot then
		local abilityService = Knit.GetService("AbilityService")
		local animations = getSwingAnimations()
		-- The server starts its own count over every time the staff comes out.
		swingIndex = 0

		local function playSwing(animationId: string?)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if not animator or type(animationId) ~= "string" then
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

			swingIndex = swingIndex % 3 + 1
			playSwing(animations[swingIndex])
			drawSwing(root.Position, { Caster = character, Swing = swingIndex, Local = true })
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
		if staff then
			staff:Destroy()
		end
	end
end
