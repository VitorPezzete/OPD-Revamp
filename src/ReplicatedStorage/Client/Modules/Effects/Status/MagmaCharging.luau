--!strict
--[[
	Magma fruit - Great Eruption while charging: magma dripping from the hand that will
	throw the fist, with the looping "Magma Flow" sound.
	Status value: "<Right|Left>|<fruit colors>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Magma.Power1["Hand Fire"] (a
	ParticleEmitter). Both fruit colors; dark with armament haki, like the legacy hand fire.

	Owner only: the charge animation of that hand (the wind-up clip four times faster
	than authored, then the held clip). It replicates through the Animator.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local WIND_UP_SPEED = 4

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"
	local created: { Instance } = {}
	local hakiConnection: RBXScriptConnection? = nil

	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local template = EffectAssets.FindFruit("Magma", "Power1", "Hand Fire")
	if arm and template and template:IsA("ParticleEmitter") then
		local fire = template:Clone()
		for _, child in fire:GetChildren() do
			child:Destroy()
		end

		local authored = fire.Color
		local primary, secondary = FruitColor.Parse(fields[2] or "")
		local function paint()
			if character:GetAttribute(HAKI_ATTRIBUTE) then
				fire.Color = HAKI_COLOR
			elseif primary and secondary then
				fire.Color = FruitColor.ToSequence(primary, secondary)
			else
				fire.Color = authored
			end
		end
		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

		fire.Enabled = true
		fire.Parent = arm
		table.insert(created, fire)
	end

	local definition = (SoundConfig :: any).SFX.Elemental.Magma["Magma Flow"]
	if arm and definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.Looped = true
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = arm
		sound:Play()
		table.insert(created, sound)
	end

	local active = true
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if isLocal and animator then
		local anims = AnimationConfig.FruitAnims
		local windUp = Animations.Get(animator, if left then anims.Punch1LeftCharge else anims.Punch1RightCharge)
		local held = Animations.Get(animator, if left then anims.Punch1LeftCharged else anims.Punch1RightCharged)
		tracks = { windUp, held }
		stoppedConnection = windUp.Stopped:Connect(function()
			if active then
				held:Play()
			end
		end)
		windUp:Play(0.1, 1, WIND_UP_SPEED)
	end

	return function()
		active = false
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end
		if hakiConnection then
			hakiConnection:Disconnect()
		end
		for _, instance in created do
			instance:Destroy()
		end
	end
end
