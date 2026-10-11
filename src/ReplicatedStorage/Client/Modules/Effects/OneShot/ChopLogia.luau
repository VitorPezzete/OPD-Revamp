--!strict
--[[
	Chop fruit - a cut passed through: the body falls apart and snaps back.
	params: { Caster: Model }
	Clip: ReplicatedStorage.Assets.Models.Fruits.Chop.Logia.Animation (an Animation
	instance; its id is not in AnimationConfig), played at four times its speed like the
	legacy server did.

	Only the owner's client plays it: the Animator replicates it to everyone else.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Client.Util.Animations)
local EffectAssets = require(script.Parent.Parent.Util.EffectAssets)

local SPEED = 4

return function(_origin: Vector3, params: { [string]: any }?)
	local character = params and params.Caster
	if typeof(character) ~= "Instance" or character ~= Players.LocalPlayer.Character then
		return
	end

	local animation = EffectAssets.FindFruit("Chop", "Logia", "Animation")
	local animator = Animations.FindAnimator(character)
	if not animation or not animation:IsA("Animation") or animation.AnimationId == "" or not animator then
		return
	end

	Animations.Play(animator, animation.AnimationId, 0.1, 1, SPEED)
end
