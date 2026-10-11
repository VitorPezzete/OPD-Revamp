--!strict
--[[
	Rumble fruit - Lightning Blitz while charging: electricity gathering around the
	casting hand, wider the longer the key is held, and the looping crackle.
	Status value: "<melee level scale>|<fruit colors>|<Right or Left>".

	The legacy "ball" (a borrowed Chilly mesh) was fully transparent: only its growing
	scale mattered, as the reach of the sparks. That reach is reproduced directly: it
	grows linearly for 3 seconds up to 7.5 * level scale (as a mesh scale), and a spark
	may land up to scale * sqrt(3) * 0.1 studs from the hand on each axis.

	Everyone sees a chain of sparks, one every 0.1 s, each lasting 0.5 s (first fruit
	color, "Toothpaste" cyan without one). The owner sees a second, much denser chain
	(one every 0.02 s, 0.15 s each): the legacy game ran that one in a LocalScript.

	Owner only, as the legacy client did:
	- the charge pose: the wind-up clip, then the held clip (FruitAnims.Punch1*Charge
	  then Punch1*Charged), replicated by the Animator;
	- the character keeps facing the mouse;
	- when the status ends, the punch clip (FruitAnims.Punch1*Punch) played 30 times
	  faster; not when the charge was cut short by a stun, a seal or death.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.Parent.OneShot.RumbleBolt)

local HAND_OFFSET = CFrame.new(0, -1, 0)

local START_SCALE = 0.1
local MAX_SCALE = 7.5
local GROW_TIME = 3
-- Legacy reach per axis: random(-100, 100) * (|mesh scale| * 0.002) / 2.
local REACH_PER_SCALE = math.sqrt(3) * 0.1
local SPARK_INTERVAL = 0.1
local SPARK_LIFE = 0.5
local OWNER_SPARK_INTERVAL = 0.02
local OWNER_SPARK_LIFE = 0.15
local SPARK_THICKNESS = 0.1
local SINGLE_SEGMENT = 4096

local RENDER_STEP_NAME = "RumbleBlitzFacing"
local STUN_ATTRIBUTE = "Stunned"
local RELEASE_FADE = 0.1
local RELEASE_SPEED = 30

local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local fields = EffectAssets.Unpack(value)
	local levelScale = tonumber(fields[1]) or 1
	local color = FruitColor.Parse(fields[2] or "")
	local left = fields[3] == "Left"

	local found = character:FindFirstChild(if left then "Left Arm" else "Right Arm")
	if not found or not found:IsA("BasePart") then
		return noop
	end
	local arm: BasePart = found

	local sound: Sound? = nil
	local sfx = (SoundConfig :: any).SFX
	local group = sfx and sfx.Elemental and sfx.Elemental.Rumble
	local definition = group and group["Electricity Loop"]
	if definition then
		local created = Instance.new("Sound")
		created.SoundId = definition.Id
		created.Volume = definition.Volume or 0.25
		created.PlaybackSpeed = definition.Speed or 1
		created.Looped = true
		created.Parent = arm
		created:Play()
		sound = created
	end

	local alive = true
	local started = os.clock()

	-- A chain of sparks around the hand: each one starts where the previous one ended.
	local function crackle(interval: number, life: number)
		task.spawn(function()
			local previous = (arm.CFrame * HAND_OFFSET).Position
			while alive do
				task.wait(interval)
				if not alive or not arm:IsDescendantOf(game) then
					break
				end

				local progress = math.clamp((os.clock() - started) / GROW_TIME, 0, 1)
				local meshScale = START_SCALE + (MAX_SCALE * levelScale - START_SCALE) * progress
				local reach = math.max(meshScale, START_SCALE) * REACH_PER_SCALE
				local hand = (arm.CFrame * HAND_OFFSET).Position
				local point = hand
					+ Vector3.new(
						(math.random() * 2 - 1) * reach,
						(math.random() * 2 - 1) * reach,
						(math.random() * 2 - 1) * reach
					)
				drawBolt(previous, {
					Target = point,
					Color = color,
					Thickness = math.max(SPARK_THICKNESS * levelScale, 0.05),
					Life = life,
					Step = SINGLE_SEGMENT,
				})
				previous = point
			end
		end)
	end

	crackle(SPARK_INTERVAL, SPARK_LIFE)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local foundRoot = character:FindFirstChild("HumanoidRootPart")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local anims = AnimationConfig.FruitAnims
	local tracks: { AnimationTrack } = {}
	local stoppedConnection: RBXScriptConnection? = nil
	local facing = false

	if isLocal then
		crackle(OWNER_SPARK_INTERVAL, OWNER_SPARK_LIFE)

		if animator then
			local windUp = Animations.Get(animator, if left then anims.Punch1LeftCharge else anims.Punch1RightCharge)
			local held = Animations.Get(animator, if left then anims.Punch1LeftCharged else anims.Punch1RightCharged)
			tracks = { windUp, held }
			stoppedConnection = windUp.Stopped:Connect(function()
				if alive then
					held:Play()
				end
			end)
			windUp:Play()
		end

		if humanoid and foundRoot and foundRoot:IsA("BasePart") then
			-- Typed copies: the closure below cannot rely on the narrowing above.
			local facingHumanoid: Humanoid, root: BasePart = humanoid, foundRoot
			local mouse = Players.LocalPlayer:GetMouse()
			facing = true
			RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Last.Value, function()
				if facingHumanoid.Sit then
					return
				end
				local position = root.Position
				local target = mouse.Hit.Position
				local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
				if flat.Magnitude > 0.1 then
					root.CFrame = CFrame.lookAt(position, position + flat)
				end
			end)
		end
	end

	return function()
		alive = false
		if sound then
			sound:Destroy()
		end
		if facing then
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
		end
		if stoppedConnection then
			stoppedConnection:Disconnect()
		end
		for _, track in tracks do
			track:Stop()
		end

		local released = isLocal
			and humanoid ~= nil
			and humanoid.Health > 0
			and character:IsDescendantOf(game)
			and not character:GetAttribute(STUN_ATTRIBUTE)
			and not character:GetAttribute(AbilityConfig.Status.AbilitiesDisabled)
		if animator and released then
			Animations.Play(
				animator,
				if left then anims.Punch1LeftPunch else anims.Punch1RightPunch,
				RELEASE_FADE,
				1,
				RELEASE_SPEED
			)
		end
	end
end
