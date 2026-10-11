--!strict
--[[
	Vampire fruit - Transform: the half-bat form.
	Status value: "<wing beat speed in studs per second>|<fruit color string>".

	Everyone: two ears on the head and a wing on each arm.
	Templates: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power6.BatLeftEar,
	BatRightEar, LeftBatWing, RightBatWing - mesh parts carrying a "ManualWeld" whose
	offsets are authored; only its Part0 has to be pointed at the limb. Custom colors
	paint them with the first color.

	Owner only: every jump request is a wing beat, in the air too, so holding jump
	climbs. A beat is the legacy mover itself: a BodyVelocity pushing up at the given
	speed with MaxForce (0, 400000, 0) and the default P, alive for one legacy `wait()`
	(Shared.Util.Push).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Push = require(ReplicatedStorage.Shared.Util.Push)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local DEFAULT_BEAT_SPEED = 10
local BEAT_FORCE = Vector3.new(0, 400000, 0)
-- A legacy `wait()`: one 30 Hz step.
local BEAT_TIME = 1 / 30
-- Template name -> the limb it is welded to.
local PIECES = {
	BatLeftEar = "Head",
	BatRightEar = "Head",
	LeftBatWing = "Left Arm",
	RightBatWing = "Right Arm",
}

local function addPieces(character: Model, colors: string): { Instance }
	local created: { Instance } = {}
	local primary = FruitColor.Parse(colors)

	for templateName, limbName in PIECES do
		local template = EffectAssets.FindFruit("Vampire", "Power6", templateName)
		local limb = character:FindFirstChild(limbName)
		if not template or not template:IsA("BasePart") or not limb or not limb:IsA("BasePart") then
			continue
		end

		local piece = template:Clone()
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		if primary then
			piece.Color = primary
		end

		local weld = piece:FindFirstChild("ManualWeld")
		if weld and weld:IsA("JointInstance") then
			weld.Part0 = limb
			if not weld.Part1 then
				weld.Part1 = piece
			end
		else
			local fallback = Instance.new("Weld")
			fallback.Part0 = limb
			fallback.Part1 = piece
			fallback.Parent = piece
		end

		piece.Parent = limb
		table.insert(created, piece)
	end
	return created
end

local function startWingBeats(character: Model, beatSpeed: number): (() -> ())?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not foundRoot or not foundRoot:IsA("BasePart") then
		return nil
	end
	local root: BasePart = foundRoot

	local track: AnimationTrack? = nil
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animationId = AnimationConfig.FruitAnims.VampireHZ
	if animator and type(animationId) == "string" then
		track = Animations.Get(animator, animationId)
	end

	local connection = UserInputService.JumpRequest:Connect(function()
		if character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled) or character:GetAttribute("Stunned") then
			return
		end
		if humanoid.Health <= 0 or humanoid.Sit then
			return
		end

		Push.Apply(root, Vector3.new(0, beatSpeed, 0), BEAT_TIME, BEAT_FORCE)
		if track then
			-- The legacy beat: heavily weighted, three times as fast, restarted by
			-- every request.
			track:Play(0.1, 10, 3)
		end
	end)

	return function()
		connection:Disconnect()
		if track then
			track:Stop()
		end
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local beatSpeed = tonumber(fields[1]) or DEFAULT_BEAT_SPEED
	local pieces = addPieces(character, fields[2] or "")
	local stopBeats = if isLocal then startWingBeats(character, beatSpeed) else nil

	return function()
		if stopBeats then
			stopBeats()
		end
		for _, piece in pieces do
			piece:Destroy()
		end
	end
end
