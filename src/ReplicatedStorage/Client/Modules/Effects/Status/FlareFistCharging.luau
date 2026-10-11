--!strict
--[[
	Flare fruit - Fire Fist while charging: fire around the punching hand.
	Status value: "<Right|Left>|<fruit color string>".
	Template: ReplicatedStorage.Assets.Models.Fruits.Flare.Power2["Flare Fire"] (a part
	holding the emitter), welded half a stud under the centre of the arm as in the
	legacy game.

	Both fruit colors on the emitter; dark for as long as armament haki is on (the legacy
	fire followed the haki live), the authored colors otherwise.
	Owner only: the charge animation (wind-up clip, then the held loop). The punch belongs
	to the FlareFist one-shot, so an interrupted charge just stops.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_ATTRIBUTE = "Haki"
local HAKI_COLOR = ColorSequence.new(Color3.new(0.051, 0, 0.133), Color3.new(0.098, 0.067, 0.098))
local HAND_OFFSET = CFrame.new(0, 0.5, 0)

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local left = fields[1] == "Left"
	local primary, secondary = FruitColor.Parse(fields[2] or "")

	local fire: BasePart? = nil
	local hakiConnection: RBXScriptConnection? = nil

	local arm = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	local template = EffectAssets.FindFruit("Flare", "Power2", "Flare Fire")
	if arm and arm:IsA("BasePart") and template and template:IsA("BasePart") then
		local part = template:Clone()
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true

		local authored: { [ParticleEmitter]: ColorSequence } = {}
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("LuaSourceContainer") then
				descendant:Destroy()
			elseif descendant:IsA("ParticleEmitter") then
				authored[descendant] = descendant.Color
			end
		end

		local function paint()
			local haki = character:GetAttribute(HAKI_ATTRIBUTE)
			for emitter, color in authored do
				emitter.Color = if haki
					then HAKI_COLOR
					elseif primary and secondary then FruitColor.ToSequence(primary, secondary)
					else color
			end
		end
		paint()
		hakiConnection = character:GetAttributeChangedSignal(HAKI_ATTRIBUTE):Connect(paint)

		local weld = Instance.new("Weld")
		weld.Part0 = arm
		weld.Part1 = part
		weld.C1 = HAND_OFFSET
		weld.Parent = part

		part.Parent = arm
		fire = part
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
		-- The loop clips are shared with other charging effects, which loop them.
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
		if hakiConnection then
			hakiConnection:Disconnect()
		end
		if fire then
			fire:Destroy()
		end
	end
end
