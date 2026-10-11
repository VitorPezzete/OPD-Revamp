--!strict
--[[
	Rumble fruit - Lightning Blitz: the bolt from the hand to the aim point and the ball
	of lightning where it lands.
	origin: the casting hand. params: { Target: Vector3, Size: number (melee affinity),
	Thickness: number, Colors: string, Caster: Model }

	Bolt: jagged, made of round neon segments (first fruit color, "Toothpaste" cyan
	without one) that go slightly translucent over the 0.5 s they last. Ball:
	ReplicatedStorage.Assets.Models.Fruits.Rumble.Power3.FinalPart scaled by Size, in the
	middle of the bolt's last segment and turned along it (as in the legacy game), fading
	for the 0.5 s it exists (the legacy fade was a 2 s tween cut short by the removal; the
	same slope is kept).
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)
local drawBolt = require(script.Parent.RumbleBolt)

local BOLT_LIFE = 0.5
local BOLT_FADE = 1 / 6
local BALL_LIFE = 0.5
local BALL_FADE_TIME = 2

return function(origin: Vector3, params: { [string]: any }?)
	local target = params and params.Target
	if not params or typeof(target) ~= "Vector3" then
		return
	end

	local primary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local caster = params.Caster
	local root = if typeof(caster) == "Instance" then caster:FindFirstChild("HumanoidRootPart") else nil
	local sfx = (SoundConfig :: any).SFX
	local group = sfx and sfx.Elemental and sfx.Elemental.Rumble
	local definition = group and group.Electricity
	if root and definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume or 0.25
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, 5)
	end

	local last = drawBolt(origin, {
		Target = target,
		Color = primary,
		Thickness = params.Thickness,
		Jitter = 2,
		Life = BOLT_LIFE,
		Fade = BOLT_FADE,
		Cylinder = true,
	})

	local template = EffectAssets.FindFruit("Rumble", "Power3", "FinalPart")
	if not template or not template:IsA("BasePart") then
		return
	end

	local ball = template:Clone()
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Size = template.Size * (if type(params.Size) == "number" then params.Size else 1)
	if primary then
		ball.Color = primary
	end
	ball.CFrame = last or CFrame.new(target)
	ball.Parent = World.Effects()

	TweenService:Create(ball, TweenInfo.new(BALL_FADE_TIME, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	Debris:AddItem(ball, BALL_LIFE)
end
