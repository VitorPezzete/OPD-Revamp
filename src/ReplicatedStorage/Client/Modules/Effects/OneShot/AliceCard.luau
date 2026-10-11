--!strict
--[[
	Alice fruit - Cards of Fate: the playing card homing on its target.
	params: { Target: Model?, Position: Vector3?, Speed: number, Image: number }   (plus
	Caster, Colors). Without a Target the card flies to Position (a throw at no one).
	Template: ReplicatedStorage.Assets.Models.Fruits.Alice.Power1.Card (a part with
	"Top" and "Bottom" surface guis, each holding an ImageLabel).

	Purely cosmetic: the server applies the hit after distance / speed seconds. The card
	leaves the caster's right hand and flies like the legacy one: it always moves along
	its own heading, which starts as the template's rotation and turns a quarter of the
	way towards the target's root every 1/60 s, so it swerves out of the hand before it
	straightens. It disappears within 5 studs of the target.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local HAND = "Right Arm"
local FACES = { "Top", "Bottom" }
local HIT_DISTANCE = 5
local MAX_LIFETIME = 7
-- Past the straight flight time by this much, a card that keeps circling is dropped.
local LATE_SECONDS = 1.5
local THROW_ANIMATION_SPEED = 32
-- Share of the remaining turn made per legacy step (the server's 60 Hz Heartbeat).
local STEER = 0.25
local STEER_RATE = 60

local random = Random.new()

local function playThrow(caster: Instance)
	if caster ~= Players.LocalPlayer.Character then
		return
	end

	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		Animations.Play(animator, AnimationConfig.FruitAnims.Punch1RightPunch, 0.01, 1, THROW_ANIMATION_SPEED)
	end
end

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	local speed = params and params.Speed
	local caster = params and params.Caster
	local fixedGoal = params and params.Position
	local hasTarget = typeof(target) == "Instance"
	if (not hasTarget and typeof(fixedGoal) ~= "Vector3") or type(speed) ~= "number" or speed <= 0 then
		return
	end

	if typeof(caster) == "Instance" then
		playThrow(caster)
	end

	local template = EffectAssets.FindFruit("Alice", "Power1", "Card")
	local targetRoot = if hasTarget then target:FindFirstChild("HumanoidRootPart") else nil
	if not template or not template:IsA("BasePart") then
		return
	end
	if hasTarget and not (targetRoot and targetRoot:IsA("BasePart")) then
		return
	end
	local startGoal: Vector3 = if targetRoot then targetRoot.Position else fixedGoal

	local card = template:Clone()
	card.Anchored = true
	card.CanCollide = false
	card.CanQuery = false
	card.CanTouch = false

	local image = params and params.Image
	if type(image) == "number" then
		for _, faceName in FACES do
			local face = card:FindFirstChild(faceName)
			local label = face and face:FindFirstChild("ImageLabel")
			if label and label:IsA("ImageLabel") then
				label.Image = `rbxassetid://{image}`
			end
		end
	end

	local hand = if typeof(caster) == "Instance" then caster:FindFirstChild(HAND) else nil
	local position = if hand and hand:IsA("BasePart") then hand.Position else origin
	local tilt = CFrame.Angles(0, 0, math.rad(random:NextInteger(-90, 90)))
	local rotation = card.CFrame.Rotation
	local heading = rotation * tilt:Inverse()
	local lifetime = math.min(MAX_LIFETIME, (startGoal - position).Magnitude / speed + LATE_SECONDS)
	card.CFrame = CFrame.new(position) * rotation
	card.Parent = World.Effects()

	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		elapsed += deltaTime

		local goal = startGoal
		if hasTarget then
			local root = target:FindFirstChild("HumanoidRootPart")
			if target.Parent == nil or not root or not root:IsA("BasePart") then
				connection:Disconnect()
				card:Destroy()
				return
			end
			goal = root.Position
		end
		if elapsed > lifetime then
			connection:Disconnect()
			card:Destroy()
			return
		end

		if (goal - position).Magnitude > 1e-3 then
			local turn = 1 - (1 - STEER) ^ (deltaTime * STEER_RATE)
			heading = heading:Lerp(CFrame.lookAt(Vector3.zero, goal - position), turn)
		end
		position += heading.LookVector * (speed * deltaTime)
		card.CFrame = CFrame.new(position) * heading * tilt

		if (position - goal).Magnitude < HIT_DISTANCE then
			connection:Disconnect()
			card:Destroy()
		end
	end)
end
