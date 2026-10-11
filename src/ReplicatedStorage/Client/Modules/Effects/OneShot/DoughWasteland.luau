--!strict
--[[
	Dough fruit - Mochi Wasteland: the pool of mochi.
	params: { Factor: number (f), Colors: string }; `origin` is the pool's centre (3 studs
	below the user's root at the press).
	Templates: ReplicatedStorage.Assets.Models.Fruits.Dough.Effects["Mochi Wasteland"].Pool
	(a MeshPart with a "Mochi" ParticleEmitter) and .Formating (a ParticleEmitter).

	As the source: a burst of 10 "Formating" particles and the "Mochi Formating" sound at
	the centre; the pool starts as a 5 * f ball, flattens out to 500 * f wide and
	2.5 * f tall over 10 s, then shrinks to nothing over 20 s and is removed at 30 s.
	Its 250 * f radius at the widest is the server's cover radius.
	Custom colors: pool = first, both particles = second.
	The pool keeps the collision settings authored on the template.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local GROW_TIME = 10
local SHRINK_TIME = 20
local LIFETIME = 30

return function(origin: Vector3, params: { [string]: any }?)
	local factor = params and params.Factor
	if not params or type(factor) ~= "number" or factor <= 0 then
		return
	end
	local primary, secondary = FruitColor.Parse(if type(params.Colors) == "string" then params.Colors else "")

	local burst = Instance.new("Attachment")
	burst.WorldPosition = origin
	burst.Parent = Workspace.Terrain
	Debris:AddItem(burst, 1)

	local particles = EffectAssets.FindFruit("Dough", "Effects", "Mochi Wasteland", "Formating")
	if particles and particles:IsA("ParticleEmitter") then
		local emitter = particles:Clone()
		if secondary then
			emitter.Color = ColorSequence.new(secondary)
		end
		emitter.Parent = burst
		emitter:Emit(10)
	end

	local definition = (SoundConfig :: any).Fruits.Dough.MochiFormating
	if definition then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = origin
		holder.Parent = Workspace.Terrain
		local sound = Instance.new("Sound")
		sound.SoundId = definition.Id
		sound.Volume = definition.Volume
		sound.PlaybackSpeed = definition.Speed or 1
		sound.Parent = holder
		sound:Play()
		Debris:AddItem(holder, 2.5)
	end

	local template = EffectAssets.FindFruit("Dough", "Effects", "Mochi Wasteland", "Pool")
	if not template or not template:IsA("BasePart") then
		return
	end
	local pool = template:Clone()
	pool.Anchored = true
	pool.Size = Vector3.new(5 * factor, 5 * factor, 5 * factor)
	pool.Position = origin
	if primary and secondary then
		pool.Color = primary
		local mochi = pool:FindFirstChild("Mochi")
		if mochi and mochi:IsA("ParticleEmitter") then
			mochi.Color = ColorSequence.new(secondary)
		end
	end
	pool.Parent = World.Effects()
	Debris:AddItem(pool, LIFETIME)

	local grow = TweenService:Create(pool, TweenInfo.new(GROW_TIME, Enum.EasingStyle.Linear), {
		Size = Vector3.new(500 * factor, 2.5 * factor, 500 * factor),
	})
	grow:Play()
	grow.Completed:Wait()

	if pool.Parent then
		TweenService:Create(pool, TweenInfo.new(SHRINK_TIME, Enum.EasingStyle.Linear), { Size = Vector3.zero }):Play()
	end
end
