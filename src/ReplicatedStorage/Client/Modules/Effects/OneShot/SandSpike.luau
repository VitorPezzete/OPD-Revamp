--!strict
--[[
	Sand fruit - Sand Spike.
	params: { CFrame: CFrame (centre and tilt of the spike), Scale: number (sniper
	          affinity * level scale), Haki: boolean, Animation: number (1-4),
	          Colors: string, Caster: Model }
	Templates: ReplicatedStorage.Assets.Models.Fruits.Sand.Power2.SandSpike (MeshPart) and
	.SandTrigger (ParticleEmitter, a puff on the caster's right arm for 0.25 s).

	The spike grows from nothing to template size * Scale in 0.1 s and stays 6 seconds,
	as in the legacy game. It keeps the template's collisions: the legacy spike was a
	solid server part, here each client collides its own character with its own copy.
	The caster's own client plays the cast animation (one of the four SandSpike clips,
	at the legacy speed of 15); it replicates from there.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local HAKI_COLOR = Color3.fromRGB(25, 12, 25)
local GROW_INFO = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local START_SIZE = Vector3.new(0.1, 0.1, 0.1)
local LIFETIME = 6
local TRIGGER_SECONDS = 0.25
local ANIMATION_SPEED = 15

local function playCast(caster: Instance, index: number)
	if caster ~= Players.LocalPlayer.Character then
		return
	end

	local id = (AnimationConfig :: any).Fruits.Sand[`SandSpike{index}`]
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator and type(id) == "string" then
		local track = Animations.Get(animator, id)
		track:Play()
		track:AdjustSpeed(ANIMATION_SPEED)
	end
end

return function(_origin: Vector3, params: { [string]: any }?)
	if not params or typeof(params.CFrame) ~= "CFrame" then
		return
	end
	local scale: number = if type(params.Scale) == "number" then params.Scale else 1
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local caster = params.Caster
	if typeof(caster) == "Instance" then
		playCast(caster, if type(params.Animation) == "number" then params.Animation else 1)

		local arm = caster:FindFirstChild("Right Arm")
		local trigger = EffectAssets.FindFruit("Sand", "Power2", "SandTrigger")
		if arm and trigger and trigger:IsA("ParticleEmitter") then
			local puff = trigger:Clone()
			if primary and secondary and not params.Haki then
				puff.Color = FruitColor.ToSequence(primary, secondary)
			end
			puff.Enabled = true
			puff.Parent = arm
			Debris:AddItem(puff, TRIGGER_SECONDS)
		end
	end

	local template = EffectAssets.FindFruit("Sand", "Power2", "SandSpike")
	if not template or not template:IsA("BasePart") or scale <= 0 then
		return
	end

	local spike = template:Clone()
	for _, descendant in spike:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	spike.Anchored = true
	spike.CanTouch = false
	if params.Haki then
		spike.Color = HAKI_COLOR
	elseif primary then
		spike.Color = primary
	end
	spike.Size = START_SIZE
	spike.CFrame = params.CFrame
	spike.Parent = World.Effects()

	TweenService:Create(spike, GROW_INFO, { Size = template.Size * scale }):Play()
	Debris:AddItem(spike, LIFETIME)
end
