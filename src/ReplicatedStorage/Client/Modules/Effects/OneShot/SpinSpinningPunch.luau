--!strict
--[[
	Spin fruit - Spinning Punch: the punch animation.

	Only the caster's own client plays it; animations played by the owner replicate to
	everyone else, so playing it on every client would stack two tracks.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

-- The legacy call: Play(0.1, 1, 8).
local FADE = 0.1
local SPEED = 8

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	if typeof(caster) ~= "Instance" or caster ~= Players.LocalPlayer.Character then
		return
	end

	local humanoid = caster:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local id = (AnimationConfig.FruitAnims :: any).SpinPunch
	if not animator or type(id) ~= "string" then
		return
	end

	Animations.Play(animator, id, FADE, 1, SPEED)
end
