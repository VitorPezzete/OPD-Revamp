--!strict
--[[
	Slash fruit - Slash Claws: three claws on each hand while the status is active, plus
	(for the owner) the click that throws a cut.

	Status value: "<fruit slot>|<ability slot>|<claw length>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Slash.Power1.Claws (a part holding
	Claw1..Claw3, each with a "default" effect child, and a "MainWeld" whose Part1 is the
	part itself). One copy per arm; the claws slide out of the hand over 0.5 s and back
	in over 0.5 s when the status ends.

	First fruit color on the claws, second on their "default" child. As in the legacy
	game armament haki does not tint the claws, only the cuts they throw.

	Clicking: each click sends phase 3 of the ability with the mouse position; cooldown,
	hitbox and damage are decided by the server. The swing animation is played here and
	replicated by the Animator.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
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
local CUT_COOLDOWN = 0.25
local EXTEND_TIME = 0.5
local MAX_AIM_DISTANCE = AbilityConfig.MaxAimDistance * 0.9
-- The legacy swing: the clip played very fast and over-weighted.
local SWING_FADE = 0.2
local SWING_WEIGHT = 3
local SWING_SPEED = 12

local CLAW_NAMES = { "Claw1", "Claw2", "Claw3" }
local ARMS = {
	{ Name = "Right Arm", Rotation = CFrame.Angles(-math.rad(90), 0, 0) },
	{ Name = "Left Arm", Rotation = CFrame.Angles(0, -math.rad(180), 0) * CFrame.Angles(-math.rad(90), 0, 0) },
}

local lastCut = 0
local secondSwing = false

-- Colors a claw's "default" child, whatever kind of effect it is.
local function paintEffect(effect: Instance?, color: Color3)
	if not effect then
		return
	end
	if effect:IsA("BasePart") then
		effect.Color = color
	elseif effect:IsA("ParticleEmitter") or effect:IsA("Trail") or effect:IsA("Beam") then
		effect.Color = ColorSequence.new(color)
	elseif effect:IsA("Light") then
		effect.Color = color
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local length = tonumber(fields[3]) or 0.5
	local primary, secondary = FruitColor.Parse(fields[4] or "")

	local claws: { BasePart } = {}
	-- Weld of each claw and its retracted C0.
	local welds: { [JointInstance]: CFrame } = {}
	local tracks: { [string]: AnimationTrack } = {}
	local inputConnection: RBXScriptConnection? = nil

	local template = EffectAssets.FindFruit("Slash", "Power1", "Claws")
	if template and template:IsA("BasePart") then
		for _, armInfo in ARMS do
			local arm = character:FindFirstChild(armInfo.Name)
			if not arm or not arm:IsA("BasePart") then
				continue
			end

			local claw = template:Clone()
			for _, descendant in claw:GetDescendants() do
				if descendant:IsA("LuaSourceContainer") then
					descendant:Destroy()
				elseif descendant:IsA("BasePart") then
					descendant.Anchored = false
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.CanTouch = false
					descendant.Massless = true
				end
			end
			claw.Anchored = false
			claw.CanCollide = false
			claw.CanQuery = false
			claw.CanTouch = false
			claw.Massless = true

			local found = claw:FindFirstChild("MainWeld")
			local weld: JointInstance
			if found and found:IsA("JointInstance") then
				weld = found
			else
				if found then
					found:Destroy()
				end
				weld = Instance.new("Weld")
				weld.Name = "MainWeld"
				weld.Part1 = claw
				weld.Parent = claw
			end
			weld.Part0 = arm
			weld.C0 = armInfo.Rotation
			claw.CFrame = arm.CFrame
			claw.Parent = arm
			table.insert(claws, claw)
			welds[weld] = armInfo.Rotation

			TweenService:Create(weld, TweenInfo.new(EXTEND_TIME), {
				C0 = CFrame.new(0, -length, 0) * armInfo.Rotation,
			}):Play()
		end
	end

	if primary and secondary then
		for _, claw in claws do
			for _, name in CLAW_NAMES do
				local part = claw:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					part.Color = primary
					paintEffect(part:FindFirstChild("default"), secondary)
				end
			end
		end
	end

	if isLocal and fruitSlot and abilitySlot then
		local abilityService = Knit.GetService("AbilityService")
		local mouse = Players.LocalPlayer:GetMouse()

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
			if not root or now - lastCut < CUT_COOLDOWN then
				return
			end
			lastCut = now

			local aim = mouse.Hit.Position
			local offset = aim - root.Position
			if offset.Magnitude > MAX_AIM_DISTANCE then
				aim = root.Position + offset.Unit * MAX_AIM_DISTANCE
			end
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, aim)

			secondSwing = not secondSwing
			local anims = AnimationConfig.Fruits.Slash
			playSwing(if secondSwing then anims.Anim1 else anims.Anim2)
		end)
	end

	return function()
		if inputConnection then
			inputConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop(0)
		end
		for weld, retracted in welds do
			TweenService:Create(weld, TweenInfo.new(EXTEND_TIME), { C0 = retracted }):Play()
		end
		for _, claw in claws do
			Debris:AddItem(claw, EXTEND_TIME)
		end
	end
end
