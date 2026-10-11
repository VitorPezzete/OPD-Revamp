--!strict
--[[
	Smoke fruit - Whiteout Burst: the stomp and the cloud. Purely cosmetic; damage,
	launch and suffocation are decided by the server.

	origin: the caster's root position at the release.
	params: { Factor: number (0.1 - 1, the strength of the burst), RightLeg: boolean,
	          Caster: Model, Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Smoke.Power4.ExplosionSmoke (ParticleEmitter).

	The cloud is one burst of particles from the caster's feet whose lifetime, speed,
	size and count all scale with Factor, exactly as the legacy server set them.
	The stomp animation is played by the caster's own client (it replicates through the
	Animator), very fast, as before.
]]
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local FEET_OFFSET = CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.rad(90))
local MAX_LIFETIME = 5
local MAX_SPEED = 1000
local MAX_SIZE = 50
local MAX_PARTICLES = 100
local DRAG = 10
local STOMP_FADE = 0.1
local STOMP_SPEED = 15

local function playStomp(caster: Model, rightLeg: boolean)
	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local animationId = if rightLeg
		then AnimationConfig.FruitAnims.QuakeRightLeg
		else AnimationConfig.FruitAnims.QuakeLeftLeg
	Animations.Play(animator, animationId, STOMP_FADE, 1, STOMP_SPEED)
end

return function(origin: Vector3, params: { [string]: any }?)
	if not params or type(params.Factor) ~= "number" then
		return
	end
	local factor: number = math.clamp(params.Factor, 0.1, 1)

	local caster = params.Caster
	if typeof(caster) == "Instance" and caster:IsA("Model") and caster == Players.LocalPlayer.Character then
		playStomp(caster, params.RightLeg == true)
	end

	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.new(origin) * FEET_OFFSET
	attachment.Parent = Workspace.Terrain
	Debris:AddItem(attachment, MAX_LIFETIME)

	local definition = (SoundConfig :: any).SFX.Elemental.Smoke["Smoke Ignite"]
	if definition then
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = attachment
		sound:Play()
	end

	local template = EffectAssets.FindFruit("Smoke", "Power4", "ExplosionSmoke")
	if not template or not template:IsA("ParticleEmitter") then
		return
	end

	local emitter = template:Clone()
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(MAX_LIFETIME * factor)
	emitter.Acceleration = Vector3.new(factor, 0, 0)
	emitter.Speed = NumberRange.new(MAX_SPEED * factor)
	emitter.Drag = DRAG
	emitter.Size = NumberSequence.new(MAX_SIZE * factor, 0)

	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")
	if primary and secondary then
		emitter.Color = FruitColor.ToSequence(primary, secondary)
	end

	emitter.Parent = attachment
	emitter:Emit(math.floor(MAX_PARTICLES * factor))
end
