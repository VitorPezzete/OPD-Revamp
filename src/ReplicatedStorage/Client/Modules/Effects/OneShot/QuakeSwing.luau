--!strict
--[[
	Quake fruit - the swing that releases a charged ability. Only the caster's own client
	plays it (the Animator replicates it); the hold clip it follows belongs to
	Effects.Status.QuakeCharging.

	params: { Kind: "Punch" | "Tsunami" | "Stomp" | "Seismic", Right: boolean, Caster: Model }

	Clips and speeds of the legacy client, all with a 0.1 s fade:
	- Tsunami: both arm swings at speed 6 (the walls come 0.5 s later);
	- Stomp: the right kick at 15 or the left one at 12 (the ball leaves 0.2 / 0.25 s later);
	- Seismic Wave: the quick punch of the charging hand at 30;
	- Quake Punch: the punch swing of the charging hand at 6.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local FADE = 0.1
local ARM_SWING_SPEED = 6
local RIGHT_KICK_SPEED = 15
local LEFT_KICK_SPEED = 12
local QUICK_PUNCH_SPEED = 30

return function(_origin: Vector3, params: { [string]: any }?)
	if not params then
		return
	end
	local caster = params.Caster
	if typeof(caster) ~= "Instance" or caster ~= Players.LocalPlayer.Character then
		return
	end
	local animator = Animations.FindAnimator(caster)
	if not animator then
		return
	end

	local anims = AnimationConfig.FruitAnims
	local right = params.Right == true
	local kind = params.Kind
	if kind == "Tsunami" then
		Animations.Play(animator, anims.QuakeRightArmSwing, FADE, 1, ARM_SWING_SPEED)
		Animations.Play(animator, anims.QuakeLeftArmSwing, FADE, 1, ARM_SWING_SPEED)
	elseif kind == "Stomp" then
		if right then
			Animations.Play(animator, anims.QuakeRightLeg, FADE, 1, RIGHT_KICK_SPEED)
		else
			Animations.Play(animator, anims.QuakeLeftLeg, FADE, 1, LEFT_KICK_SPEED)
		end
	elseif kind == "Seismic" then
		Animations.Play(animator, if right then anims.Punch1RightPunch else anims.Punch1LeftPunch, FADE, 1, QUICK_PUNCH_SPEED)
	elseif kind == "Punch" then
		Animations.Play(animator, if right then anims.RightPunchSwing else anims.LeftPunchSwing, FADE, 1, ARM_SWING_SPEED)
	end
end
