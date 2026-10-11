--!strict
--[[
	Ope fruit - Scalpel: the caster's hand thrust ("HeartSteal" clip, played very fast
	and over-weighted as in the legacy). Cosmetic only: the server decides the steal
	with a hitbox, never with this animation.

	params: { Caster: Model } (added by Ability:PlayEffect). Each client plays the clip
	locally on the caster's Animator, so it does not depend on who owns the character.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local FADE = 0.1
local WEIGHT = 3
local SPEED = 12
-- In case the asset never loads or the Stopped signal never comes.
local MAX_LIFETIME = 3

-- The track is shared: only the latest cast may cut it short.
local casts = 0

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if typeof(caster) ~= "Instance" then
		return
	end

	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end

	local track = Animations.Get(animator, AnimationConfig.FruitAnims.HeartSteal)
	track.Looped = false
	track:Play(FADE, WEIGHT, SPEED)

	casts += 1
	local cast = casts
	task.delay(MAX_LIFETIME, function()
		if casts == cast then
			track:Stop(0)
		end
	end)
end
