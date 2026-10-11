--!strict
--[[
	Candy fruit - Jawbreaker, while the key is held: syrup dripping from the throwing hand.
	Status value: "<Right|Left>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Candy.Power3.Part (a part with a
	"CandyParticle" emitter), welded half a stud up the arm as in the legacy game.

	Both fruit colors on the emitter.
	Owner only: the charge animation (wind-up clip, then the held loop).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local WELD_C1 = CFrame.new(0, 0.5, 0)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"
	local primary, secondary = FruitColor.Parse(fields[2] or "")

	local holder: BasePart? = nil
	local template = EffectAssets.FindFruit("Candy", "Power3", "Part")
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if template and template:IsA("BasePart") and arm and arm:IsA("BasePart") then
		local part = template:Clone()
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("JointInstance") then
				descendant:Destroy()
			elseif descendant:IsA("ParticleEmitter") and primary and secondary then
				descendant.Color = FruitColor.ToSequence(primary, secondary)
			end
		end
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CFrame = arm.CFrame * WELD_C1:Inverse()

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = part
		weld.C1 = WELD_C1
		weld.Parent = part

		part.Parent = arm
		holder = part
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local foundAnimator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if isLocal and foundAnimator then
		local animator: Animator = foundAnimator
		local function load(animationId: string): AnimationTrack
			local track = Animations.Get(animator, animationId)
			table.insert(tracks, track)
			return track
		end

		local anims = AnimationConfig.FruitAnims
		local windUp = load(if left then anims.ChargeLeft else anims.ChargeRight)
		local held = load(if left then anims.LoopLeft else anims.LoopRight)
		-- FruitAnims.LoopRight is shared with VampireCharging, which loops it.
		held.Looped = true
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play()
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		if holder then
			holder:Destroy()
		end
	end
end
