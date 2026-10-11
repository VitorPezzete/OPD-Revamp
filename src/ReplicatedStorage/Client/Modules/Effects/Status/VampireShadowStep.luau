--!strict
--[[
	Vampire fruit - Shadow Step: three seconds as a shadow.
	Status value: "<fly speed, 0 by day>|<fruit color string>".

	Everyone: shadow particles on the six body parts.
	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power3.VampireShadowStep
	(a ParticleEmitter). Custom colors run from the second color to the first.

	Owner only:
	- by night (fly speed above 0) the shadow flies away from the camera at that speed,
	  carried by the legacy mover itself: a BodyVelocity with MaxForce 400000 on every
	  axis and the default P, re-aimed every frame;
	- by day it plays the crawl animation instead. The step ends when the status goes,
	  never on the animation, which may fail to load in this copy of the game.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }
local FLIGHT_FORCE = 400000

local function addShadow(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local template = EffectAssets.FindFruit("Vampire", "Power3", "VampireShadowStep")
	if not template or not template:IsA("ParticleEmitter") then
		return created
	end

	local primary, secondary = FruitColor.Parse(colors)
	for _, partName in BODY_PARTS do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			local emitter = template:Clone()
			if primary and secondary then
				emitter.Color = FruitColor.ToSequence(secondary, primary)
			end
			emitter.Enabled = true
			emitter.Parent = part
			table.insert(created, emitter)
		end
	end
	return created
end

local function startFlight(character: Model, speed: number): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Sit or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local root: BasePart = foundRoot

	local velocity = Instance.new("BodyVelocity")
	velocity.Name = "VampireShadowStep"
	velocity.MaxForce = Vector3.new(FLIGHT_FORCE, FLIGHT_FORCE, FLIGHT_FORCE)
	velocity.Velocity = Vector3.zero
	velocity.Parent = root

	local connection = RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local offset = root.Position - camera.CFrame.Position
		local direction = if offset.Magnitude > 1e-3 then offset.Unit else camera.CFrame.LookVector
		velocity.Velocity = direction * speed
	end)

	return function()
		connection:Disconnect()
		velocity:Destroy()
	end
end

local function startCrawl(character: Model): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local animationId = AnimationConfig.FruitAnims.VampireCrawl
	if not animator or type(animationId) ~= "string" then
		return nil
	end

	local track = Animations.Get(animator, animationId)
	track:Play()

	return function()
		track:Stop()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local flySpeed = tonumber(fields[1]) or 0
	local shadow = addShadow(character, fields[2] or "")

	local stopOwner: (() -> ())? = nil
	if isLocal then
		stopOwner = if flySpeed > 0 then startFlight(character, flySpeed) else startCrawl(character)
	end

	return function()
		if stopOwner then
			stopOwner()
		end
		for _, emitter in shadow do
			emitter:Destroy()
		end
	end
end
