--!strict
--[[
	Venom fruit - Venom Demon: the demon of poison around the user, plus (for the owner)
	the click that claws with it.

	Status value: "<fruit slot>;<ability slot>;<fruit colors>".
	Templates, under ReplicatedStorage.Assets.Models.Fruits.Venom.Power6:
	- the forming demon: the Parts directly in the folder (DemonTorso, DemonHead, the
	  arms and the wings). DemonTorso holds one joint per other part, named after it,
	  and a `RootToRoot` joint whose Part1 becomes the character's root. Their meshes
	  grow from 0.2 (torso) / 0.1 (others) of their size over 3 s, while every joint of
	  the torso slides from the centre of the body to its authored place (one
	  Heartbeat connection for all of them, gone after the 3 s);
	- the full demon, 3 s later: the MeshParts of the FullDemon folder, attached the
	  same way except that `RootToRoot.Part0` is the root. Their `Hitbox` children were
	  the legacy Touched hitboxes and are dropped: contact is resolved on the server.
	Parts take the second fruit color and their VenomHydraCharge emitters both colors
	swapped, as in the legacy game.

	A click sends a phase 3 input for the Venom Demon ability; cooldown, hitbox and
	damage are decided by the server (clicks count from the toggle on, as in legacy).
	The swing animation is played here and replicated by the Animator.

	A player who arrives later sees the demon form again from the start.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
local CLAW_COOLDOWN = 0.5
local SWING_SPEED = 5
local SWING_FADE = 0.1

local BUILD_TIME = 3
local TORSO_NAME = "DemonTorso"
local ROOT_JOINT = "RootToRoot"
local TORSO_START_SCALE = 0.2
local PART_START_SCALE = 0.1

local lastClaw = 0
local swingRight = true

local function prepare(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or descendant.Name == "Hitbox" then
			descendant:Destroy()
		end
	end
end

-- Points the torso joint named after `part` at it.
local function attach(torso: BasePart, part: BasePart)
	for _, joint in torso:GetChildren() do
		if joint.Name == part.Name and joint:IsA("JointInstance") then
			joint.Part1 = part
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary, secondary = FruitColor.Parse(fields[3] or "")

	local alive = true
	local parts: { BasePart } = {}
	local inputConnection: RBXScriptConnection? = nil
	local slideConnection: RBXScriptConnection? = nil
	local tracks: { [string]: AnimationTrack } = {}

	local function clearParts()
		for _, part in parts do
			part:Destroy()
		end
		table.clear(parts)
	end

	local function paint(part: BasePart)
		if not primary or not secondary then
			return
		end
		part.Color = secondary
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.Color = FruitColor.ToSequence(secondary, primary)
			end
		end
	end

	--[[
		Clones every part of `folder` of the given class around the character.
		`rootIsPart0`: which end of the torso's RootToRoot joint is the character's root.
		`grow`: tween the SpecialMesh of each part up from a fraction of its size.
	]]
	local function build(folder: Instance, className: string, rootIsPart0: boolean, grow: boolean)
		local root = character:FindFirstChild("HumanoidRootPart")
		local torsoTemplate = folder:FindFirstChild(TORSO_NAME)
		if not root or not root:IsA("BasePart") or not torsoTemplate or not torsoTemplate:IsA(className) then
			return
		end

		local function add(template: Instance, startScale: number): BasePart
			local part = template:Clone() :: BasePart
			prepare(part)
			paint(part)
			part.CFrame = root.CFrame
			local mesh = part:FindFirstChildOfClass("SpecialMesh")
			if grow and mesh then
				local full = mesh.Scale
				mesh.Scale = Vector3.new(startScale, startScale, startScale)
				TweenService:Create(
					mesh,
					TweenInfo.new(BUILD_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = full }
				):Play()
			end
			table.insert(parts, part)
			return part
		end

		local torso = add(torsoTemplate, TORSO_START_SCALE)
		local rootJoint = torso:FindFirstChild(ROOT_JOINT)
		if rootJoint and rootJoint:IsA("JointInstance") then
			if rootIsPart0 then
				rootJoint.Part0 = root
			else
				rootJoint.Part1 = root
			end
		end

		for _, template in folder:GetChildren() do
			if template.Name ~= TORSO_NAME and template:IsA(className) then
				local part = add(template, PART_START_SCALE)
				attach(torso, part)
				part.Parent = character
			end
		end
		torso.Parent = character

		if grow then
			-- The legacy build-up: joint offsets go from nothing to their authored value.
			local joints: { { Joint: JointInstance, C0: CFrame, C1: CFrame } } = {}
			for _, descendant in torso:GetDescendants() do
				if descendant:IsA("Motor6D") then
					table.insert(joints, { Joint = descendant, C0 = descendant.C0, C1 = descendant.C1 })
				end
			end
			local function slide(alpha: number)
				for _, entry in joints do
					entry.Joint.C0 = CFrame.new(entry.C0.Position * alpha) * entry.C0.Rotation
					entry.Joint.C1 = CFrame.new(entry.C1.Position * alpha) * entry.C1.Rotation
				end
			end
			local elapsed = 0
			slide(0)
			local connection: RBXScriptConnection
			connection = RunService.Heartbeat:Connect(function(deltaTime: number)
				elapsed += deltaTime
				slide(math.min(elapsed / BUILD_TIME, 1))
				if elapsed >= BUILD_TIME then
					connection:Disconnect()
				end
			end)
			slideConnection = connection
		end
	end

	local forming = EffectAssets.FindFruit("Venom", "Power6")
	local full = forming and forming:FindFirstChild("FullDemon")
	if forming then
		build(forming, "Part", false, true)
	end
	task.delay(BUILD_TIME, function()
		if not alive then
			return
		end
		clearParts()
		if full then
			build(full, "MeshPart", true, false)
		end
	end)

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
			track:Play(SWING_FADE, 1, SWING_SPEED)
		end

		inputConnection = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then
				return
			end
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
				and input.KeyCode ~= Enum.KeyCode.ButtonR2
			then
				return
			end
			if character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled) then
				return
			end

			local root = character.PrimaryPart
			local now = os.clock()
			if not root or now - lastClaw < CLAW_COOLDOWN then
				return
			end
			lastClaw = now

			-- The aim point is unused by a claw; the root position always validates.
			abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, root.Position)

			local venom = AnimationConfig.Fruits.Venom
			playSwing(if swingRight then venom.RightSwing else venom.LeftSwing)
			swingRight = not swingRight
		end)
	end

	return function()
		alive = false
		if slideConnection then
			slideConnection:Disconnect()
		end
		if inputConnection then
			inputConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop(0)
		end
		clearParts()
	end
end
