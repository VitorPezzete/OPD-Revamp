--!strict
--[[
	Phoenix fruit - Phoenix Burst while charging.
	Status value: the fruit color string.

	Everyone: a wing of flames on each arm, removed a quarter of a second after the
	release as in the legacy game.
	Template: ReplicatedStorage.Assets.Models.Fruits.Phoenix.PhoenixWing.Wing. Colors: dark
	with armament haki, the fruit colors when it has an aura, else blue to yellow.

	Owner only: the wing charge clips (FruitAnims.PhoenixWingCharge, then the looped
	PhoenixWingCharged), and the body keeps facing the aim point every frame (legacy
	"P3Looker"): the same point InputController sends with the release.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local ARMS = { "Right Arm", "Left Arm" }
local WING_LINGER = 0.25
local HAKI_ATTRIBUTE = "Haki"
local HAKI_SEQUENCE = ColorSequence.new(Color3.fromRGB(16, 0, 26), Color3.fromRGB(60, 0, 97))
local DEFAULT_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.798, Color3.fromRGB(0, 208, 255)),
	ColorSequenceKeypoint.new(0.926, Color3.fromRGB(230, 250, 25)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 0)),
})

local function addWings(character: Model, colors: string): () -> ()
	local template = EffectAssets.FindFruit("Phoenix", "PhoenixWing", "Wing")
	if not template or not template:IsA("BasePart") then
		return function() end
	end

	local primary, secondary = FruitColor.Parse(colors)
	local normal = DEFAULT_SEQUENCE
	if primary and secondary then
		normal = ColorSequence.new({
			ColorSequenceKeypoint.new(0, primary),
			ColorSequenceKeypoint.new(0.798, primary),
			ColorSequenceKeypoint.new(0.926, secondary),
			ColorSequenceKeypoint.new(1, secondary),
		})
	end

	local wings: { Instance } = {}
	local emitters: { ParticleEmitter } = {}
	for _, armName in ARMS do
		local arm = character:FindFirstChild(armName)
		if not arm or not arm:IsA("BasePart") then
			continue
		end

		local wing = template:Clone()
		wing.Name = "PhoenixBurstWing"
		wing.Anchored = false
		wing.CanCollide = false
		wing.CanQuery = false
		wing.CanTouch = false
		wing.Massless = true
		for _, descendant in wing:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("ParticleEmitter") then
				table.insert(emitters, descendant)
			end
		end
		wing.CFrame = arm.CFrame

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = wing
		weld.Parent = wing

		wing.Parent = character
		table.insert(wings, wing)
	end

	local function recolor()
		local sequence = if character:GetAttribute(HAKI_ATTRIBUTE) then HAKI_SEQUENCE else normal
		for _, emitter in emitters do
			emitter.Color = sequence
		end
	end
	recolor()
	local connection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(recolor)

	return function()
		connection:Disconnect()
		for _, wing in wings do
			wing:Destroy()
		end
	end
end

-- Owner only: charge clips and facing. Returns its cleanup, or nil without a humanoid.
local function startCharge(character: Model): (() -> ())?
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not foundHumanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local humanoid: Humanoid, root: BasePart = foundHumanoid, foundRoot

	local charging = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local sharedClips = (AnimationConfig :: any).FruitAnims
	local function load(clip: string): AnimationTrack?
		local animationId = if type(sharedClips) == "table" then sharedClips[clip] else nil
		if not animator or type(animationId) ~= "string" then
			return nil
		end
		local track = Animations.Get(animator, animationId)
		table.insert(tracks, track)
		return track
	end

	local windUp = load("PhoenixWingCharge")
	local hold = load("PhoenixWingCharged")
	if hold then
		hold.Looped = true
	end
	if windUp then
		-- Purely visual: nothing depends on the clip loading or on its length.
		stoppedConnection = windUp.Stopped:Once(function()
			if charging and hold then
				hold:Play()
			end
		end)
		windUp:Play()
	elseif hold then
		hold:Play()
	end

	local inputController = Knit.GetController("InputController")
	local connection = RunService.RenderStepped:Connect(function()
		if humanoid.Sit then
			return
		end
		local position = root.Position
		local aim: Vector3 = inputController:GetAimPosition()
		local flat = Vector3.new(aim.X - position.X, 0, aim.Z - position.Z)
		if flat.Magnitude > 0.001 then
			root.CFrame = CFrame.lookAt(position, position + flat)
		end
	end)

	return function()
		charging = false
		connection:Disconnect()
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local removeWings = addWings(character, if type(value) == "string" then value else "")
	local stopCharge = if isLocal then startCharge(character) else nil

	return function()
		if stopCharge then
			stopCharge()
		end
		task.delay(WING_LINGER, removeWings)
	end
end
