--!strict
--[[
	Sand fruit - Sandstorm while charging: a small sand tornado held in one hand.
	Status value: "<R or L>|<fruit color string>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Sand.Power3.Tornado (a part with an
	Attachment holding the "Particles" emitter), welded half a stud above the hand as in
	the legacy game.

	Owner only: the legacy charge animation of that hand (FruitAnims.ChargeRight /
	ChargeLeft, then the LoopRight / LoopLeft clip once it stops). The release punch is
	played by Effects.OneShot.SandSandstorm.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local function noop() end

-- Wind-up clip, then the held one. Returns its cleanup.
local function playCharge(character: Model, left: boolean): () -> ()
	local animator = Animations.FindAnimator(character)
	if not animator then
		return noop
	end

	local anims = AnimationConfig.FruitAnims
	local windUp = Animations.Get(animator, if left then anims.ChargeLeft else anims.ChargeRight)
	local held = Animations.Get(animator, if left then anims.LoopLeft else anims.LoopRight)
	local active = true
	local connection = windUp.Stopped:Connect(function()
		if active then
			held:Play()
		end
	end)
	windUp:Play()

	return function()
		active = false
		connection:Disconnect()
		windUp:Stop()
		held:Stop()
	end
end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "L"
	local stopAnimation = if isLocal then playCharge(character, left) else noop

	local hand = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local template = EffectAssets.FindFruit("Sand", "Power3", "Tornado")
	if not hand or not hand:IsA("BasePart") or not template or not template:IsA("BasePart") then
		return stopAnimation
	end

	local tornado = template:Clone()
	tornado.Anchored = false
	tornado.CanCollide = false
	tornado.CanQuery = false
	tornado.CanTouch = false
	tornado.Massless = true

	local primary, secondary = FruitColor.Parse(fields[2] or "")
	for _, descendant in tornado:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		elseif descendant:IsA("ParticleEmitter") and primary and secondary then
			descendant.Color = FruitColor.ToSequence(primary, secondary)
		end
	end

	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = tornado
	weld.C1 = CFrame.new(0, 0.5, 0)
	weld.Parent = tornado
	tornado.Parent = hand

	return function()
		stopAnimation()
		tornado:Destroy()
	end
end
