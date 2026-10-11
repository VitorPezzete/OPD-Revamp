--!strict
--[[
	Dough fruit - the explosion of a Burning Mochi.
	params: { Factor: number (the server's blast factor e: hit radius 150 * e), Colors: string }
	Template: ReplicatedStorage.Assets.Models.Fruits.Dough.Effects["Burning Mochi"].Explosion
	(a neon part).

	As the source: the ball grows to 150 * e studs across in 0.5 * e s (Quad), then fades
	over 0.25 * e s and is removed 0.75 * e s after it appeared. Custom colors: the second.
	What is drawn is half as wide as the hit sphere, as in the source.
]]
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Configs.SoundConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local World = require(ReplicatedStorage.Shared.Util.World)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SIZE = 150
local GROW_TIME = 0.5
local FADE_TIME = 0.25
local LIFETIME = 0.75
local SOUND_LIFETIME = 2.5

local function playAt(name: string, position: Vector3, lifetime: number)
	local definition = (SoundConfig :: any).Fruits.Dough[name]
	if not definition then
		return
	end
	local holder = Instance.new("Attachment")
	holder.WorldPosition = position
	holder.Parent = Workspace.Terrain

	local sound = Instance.new("Sound")
	sound.SoundId = definition.Id
	sound.Volume = definition.Volume
	sound.PlaybackSpeed = definition.Speed or 1
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, lifetime)
end

return function(origin: Vector3, params: { [string]: any }?)
	local factor = params and params.Factor
	if type(factor) ~= "number" or factor <= 0 then
		return
	end

	playAt("Explosion", origin, SOUND_LIFETIME)

	local template = EffectAssets.FindFruit("Dough", "Effects", "Burning Mochi", "Explosion")
	if not template or not template:IsA("BasePart") then
		return
	end

	local ball = template:Clone()
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Position = origin

	local _, secondary = FruitColor.Parse(if type((params :: any).Colors) == "string" then (params :: any).Colors else "")
	if secondary then
		ball.Color = secondary
	end

	ball.Parent = World.Effects()
	Debris:AddItem(ball, LIFETIME * factor)

	local size = SIZE * factor
	local grow = TweenService:Create(ball, TweenInfo.new(GROW_TIME * factor, Enum.EasingStyle.Quad), {
		Size = Vector3.new(size, size, size),
	})
	grow:Play()
	grow.Completed:Wait()

	if ball.Parent then
		TweenService:Create(ball, TweenInfo.new(FADE_TIME * factor, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	end
end
