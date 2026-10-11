--!strict
--[[
	Rumble fruit - Overload: the discharge around the user.
	origin: the user's position. params: { Size: number (side of the damage area),
	Thickness: number, Colors: string, Caster: Model }

	- A hollow sphere (ReplicatedStorage.Assets.Models.Fruits.Rumble.Power4.SphereHollowed)
	  appears where the user stood, swells from nothing to Size in 0.25 s and fades out
	  over a second.
	- For that second, lightning crackles around the user (it follows them), reaching
	  random(-100, 100) * (|sphere size| * 0.005) / 2 studs on each axis as in the legacy
	  loop: it grows with the sphere for the first 0.25 s, up to about Size * 0.43.
	  One segment every 0.01 s (in practice one a frame).
	- The "Electricity Spread" sound.
	- The user's own client plays the discharge clip (twice as fast, over-weighted, as
	  the legacy client did); the Animator replicates it. Its id comes from the legacy
	  LocalScript and is not in AnimationConfig.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local startSparks = require(script.Parent.RumbleSparks)

local DURATION = 1
local SWELL_TIME = 0.25
local SPARK_INTERVAL = 0.01
local REACH_PER_SIZE = math.sqrt(3) * 0.25

local DISCHARGE_ANIMATION = "rbxassetid://86711511247446"
local DISCHARGE_FADE = 0.1
local DISCHARGE_WEIGHT = 3
local DISCHARGE_SPEED = 2

return function(origin: Vector3, params: { [string]: any }?)
	local options: { [string]: any } = params or {}
	local size: number = if type(options.Size) == "number" then math.max(options.Size, 0.5) else 20
	local primary = FruitColor.Parse(if type(options.Colors) == "string" then options.Colors else "")

	local caster = options.Caster
	local found = if typeof(caster) == "Instance" then caster:FindFirstChild("HumanoidRootPart") else nil
	local root: BasePart? = if found and found:IsA("BasePart") then found else nil

	if typeof(caster) == "Instance" and caster == Players.LocalPlayer.Character then
		local animator = Animations.FindAnimator(caster)
		if animator then
			local track = Animations.Get(animator, DISCHARGE_ANIMATION)
			track.Priority = Enum.AnimationPriority.Action
			track:Play(DISCHARGE_FADE, DISCHARGE_WEIGHT, DISCHARGE_SPEED)
		end
	end

	local sfx = (SoundConfig :: any).SFX
	local group = sfx and sfx.Elemental and sfx.Elemental.Rumble
	local definition = group and group["Electricity Spread"]
	if root and definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume or 0.5
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, 8)
	end

	local template = EffectAssets.FindFruit("Rumble", "Power4", "SphereHollowed")
	if template and template:IsA("BasePart") then
		local sphere = template:Clone()
		sphere.Anchored = true
		sphere.CanCollide = false
		sphere.CanQuery = false
		sphere.CanTouch = false
		sphere.CastShadow = false
		sphere.Transparency = 0
		if primary then
			sphere.Color = primary
		end
		sphere.Size = Vector3.new(0.1, 0.1, 0.1)
		sphere.CFrame = if root then root.CFrame else CFrame.new(origin)
		sphere.Parent = World.Effects()

		local linear = Enum.EasingStyle.Linear
		TweenService:Create(sphere, TweenInfo.new(SWELL_TIME, linear), { Size = Vector3.new(size, size, size) }):Play()
		TweenService:Create(sphere, TweenInfo.new(DURATION, linear), { Transparency = 1 }):Play()
		Debris:AddItem(sphere, DURATION)
	end

	local started = os.clock()
	local stopSparks = startSparks(origin, {
		Part = root,
		Range = function(): number
			-- The sphere goes from 0.1 to Size over SWELL_TIME, linearly.
			local alpha = math.clamp((os.clock() - started) / SWELL_TIME, 0, 1)
			return (0.1 + (size - 0.1) * alpha) * REACH_PER_SIZE
		end,
		Count = math.huge,
		Interval = SPARK_INTERVAL,
		Thickness = options.Thickness,
		Life = 0.5,
		Color = primary,
	})
	task.delay(DURATION, stopSparks)
end
