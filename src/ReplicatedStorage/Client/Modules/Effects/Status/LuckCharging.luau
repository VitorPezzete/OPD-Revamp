--!strict
--[[
	Luck fruit - Dice Roll, while the owner holds the key.

	Everyone sees the die growing in the left hand (to full size over the 4 s a full
	charge takes). Template: ReplicatedStorage.Assets.Models.Fruits.Luck.Power3.Visual
	(a part with a SpecialMesh named "Mesh").

	The owner also plays the charge pose; it replicates through the Animator. The throw
	animation belongs to the LuckDice one-shot, so an interrupted charge just stops.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local HAND = "Left Arm"
local CHARGE_TIME = 4
local START_SCALE = Vector3.new(0.1, 0.1, 0.1)
local FULL_SCALE = Vector3.new(1, 1, 1)

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	local die: BasePart? = nil
	local track: AnimationTrack? = nil

	local hand = character:FindFirstChild(HAND)
	local template = EffectAssets.FindFruit("Luck", "Power3", "Visual")
	if hand and hand:IsA("BasePart") and template and template:IsA("BasePart") then
		local visual = template:Clone()
		visual.Anchored = false
		visual.CanCollide = false
		visual.CanQuery = false
		visual.CanTouch = false
		visual.Massless = true

		local weld = Instance.new("Weld")
		weld.Name = "LuckDiceWeld"
		weld.Part0 = hand
		weld.Part1 = visual
		weld.C0 = CFrame.new(0, -1, 0)
		weld.Parent = visual

		local info = TweenInfo.new(CHARGE_TIME)
		local mesh = visual:FindFirstChild("Mesh")
		if mesh and mesh:IsA("SpecialMesh") then
			mesh.Scale = START_SCALE
			TweenService:Create(mesh, info, { Scale = FULL_SCALE }):Play()
		end
		TweenService:Create(weld, info, { C0 = CFrame.new(0, -2, 0) }):Play()

		visual.Parent = hand
		die = visual
	end

	if isLocal then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local loaded = Animations.Get(animator, AnimationConfig.FruitAnims.SunPos)
			loaded:Play()
			track = loaded
		end
	end

	return function()
		if die then
			die:Destroy()
		end
		if track then
			track:Stop()
		end
	end
end
