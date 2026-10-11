--!strict
--[[
	Light fruit - Sacred Jewels while firing: light pouring from both hands.

	Status value: "<fruit slot>;<ability slot>;<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Light.Power5.LightP5 (a
	ParticleEmitter), one in each arm, tinted with the first fruit color.

	Owner only: the firing animation (FruitAnims.Jewels, cosmetic) and the aim stream -
	the aim point is sent ten times a second as phase 3 inputs, about once per bolt as
	the legacy client did; the server fires the bolts, and ends the volley by itself if
	these stop coming. Facing the aim is Effects.Status.LightAiming; the bolts are the
	LightJewel one-shot.

	Owner only as well: the legacy hold. A BodyPosition (MaxForce 400000 per axis,
	default P and D) whose target follows the root every frame, so it never pulls
	anywhere and only damps: the user hangs almost still, in the air too.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local PHASE_ACTION = 3
-- With a second held ability streaming too this stays inside AbilityConfig.InputBudget.
local SEND_INTERVAL = 0.1
-- Frame times never add up exactly: a frame this close to the interval sends.
local FRAME_SLACK = 0.005
local ARMS = { "Right Arm", "Left Arm" }
local HOLD_FORCE = Vector3.new(400000, 400000, 400000)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = string.split(if type(value) == "string" then value else "", ";")
	local fruitSlot = tonumber(fields[1])
	local abilitySlot = tonumber(fields[2])
	local primary = FruitColor.Parse(fields[3] or "")

	local emitters: { Instance } = {}
	local template = EffectAssets.FindFruit("Light", "Power5", "LightP5")
	if template and template:IsA("ParticleEmitter") then
		for _, armName in ARMS do
			local arm = character:FindFirstChild(armName)
			if arm then
				local emitter = template:Clone()
				if primary then
					emitter.Color = ColorSequence.new(primary)
				end
				emitter.Enabled = true
				emitter.Parent = arm
				table.insert(emitters, emitter)
			end
		end
	end

	local aimConnection: RBXScriptConnection? = nil
	local holdConnection: RBXScriptConnection? = nil
	local hold: BodyPosition? = nil
	local track: AnimationTrack? = nil
	if isLocal then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local rootPart: BasePart = root
			local mover = Instance.new("BodyPosition")
			mover.Name = "LightJewelsHold"
			mover.MaxForce = HOLD_FORCE
			mover.Position = rootPart.Position
			mover.Parent = rootPart
			hold = mover
			holdConnection = RunService.RenderStepped:Connect(function()
				mover.Position = rootPart.Position
			end)
		end
	end
	if isLocal and fruitSlot and abilitySlot then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local loaded = Animations.Get(animator, AnimationConfig.FruitAnims.Jewels)
			loaded:Play()
			track = loaded
		end

		local abilityService = Knit.GetService("AbilityService")
		local inputController = Knit.GetController("InputController")
		local sinceSend = SEND_INTERVAL
		aimConnection = RunService.Heartbeat:Connect(function(deltaTime: number)
			sinceSend += deltaTime
			if sinceSend >= SEND_INTERVAL - FRAME_SLACK then
				sinceSend = 0
				abilityService.Input:Fire(fruitSlot, abilitySlot, PHASE_ACTION, inputController:GetAimPosition())
			end
		end)
	end

	return function()
		if aimConnection then
			aimConnection:Disconnect()
		end
		if holdConnection then
			holdConnection:Disconnect()
		end
		if hold then
			hold:Destroy()
		end

		if track then
			track:Stop()
		end
		for _, emitter in emitters do
			emitter:Destroy()
		end
	end
end
