--!strict
--[[
	Love fruit - Beam / Slave Arrow / Arrow Storm: the end of a salvo. Nothing is drawn;
	the caster's own client plays the release animation of the power, which replicates
	through the Animator (the legacy client played it once its last shot had left).

	params: { Kind: "Beam" | "Arrow" | "Storm", Caster: Model }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local RELEASES: { [string]: string } = {
	Beam = AnimationConfig.FruitAnims.LoveBeamRelease,
	Arrow = AnimationConfig.FruitAnims.SArrowRelease,
	Storm = AnimationConfig.FruitAnims.S2ArrowRelease,
}
local FADE_TIME = 0.1
local SPEED = 1.23

return function(_origin: Vector3, params: { [string]: any }?)
	local caster = params and params.Caster
	local animationId = params and RELEASES[params.Kind]
	if typeof(caster) ~= "Instance" or caster ~= Players.LocalPlayer.Character or not animationId then
		return
	end

	local animator = Animations.FindAnimator(caster)
	if animator then
		Animations.Play(animator, animationId, FADE_TIME, 1, SPEED)
	end
end
