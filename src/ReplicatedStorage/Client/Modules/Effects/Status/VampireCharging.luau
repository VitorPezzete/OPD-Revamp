--!strict
--[[
	Vampire fruit - Bat Swarm being charged: bats swirl around the charging hand, and the
	owner holds the charging pose.
	Status value: "<Right|Left>|<fruit color string>" (the hands alternate).

	Template: ReplicatedStorage.Assets.Models.Fruits.Vampire.Power5.VampireBatSwarm (a
	part with an "Effect" emitter), welded half a stud into that arm with the emitter
	spread in every direction. Custom colors use the first color.

	Owner only: the wind-up clip of that hand, then the held loop, as the legacy client
	chained them. Nothing waits on them: the pose ends when the status goes (the punch
	of the release is played by the VampireBatSwarm one-shot).
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

	local swarm: BasePart? = nil
	local template = EffectAssets.FindFruit("Vampire", "Power5", "VampireBatSwarm")
	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if template and template:IsA("BasePart") and arm and arm:IsA("BasePart") then
		local part = template:Clone()
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true

		local primary = FruitColor.Parse(fields[2] or "")
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				descendant.SpreadAngle = Vector2.new(180, 180)
				if primary then
					descendant.Color = ColorSequence.new(primary)
				end
			end
		end
		part.CFrame = arm.CFrame * WELD_C1:Inverse()

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = part
		weld.C1 = WELD_C1
		weld.Parent = part

		part.Parent = arm
		swarm = part
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local foundAnimator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if isLocal and foundAnimator then
		local animator: Animator = foundAnimator
		local anims = AnimationConfig.FruitAnims
		local windUpId = if left then anims.ChargeLeft else anims.ChargeRight
		local held = Animations.Get(animator, if left then anims.LoopLeft else anims.LoopRight)
		table.insert(tracks, held)

		-- Shared tracks keep what was set on them: set the loop on every play.
		held.Looped = true
		if Animations.IsAvailable(windUpId) then
			local windUp = Animations.Get(animator, windUpId)
			table.insert(tracks, windUp)
			stoppedConnection = windUp.Stopped:Connect(function()
				if active then
					held:Play()
				end
			end)
			windUp:Play()
		else
			-- A clip that did not download never ends: go straight to the loop.
			held:Play()
		end
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		if swarm then
			swarm:Destroy()
		end
	end
end
