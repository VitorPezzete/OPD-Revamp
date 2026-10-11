--!strict
--[[
	Barrier fruit - the crossed-fingers pose its user holds for as long as a barrier is
	up: a standing Wall / Room / Prison, a Slam in flight (1.2 s) or the Barrier Body.
	The server sets the status (the legacy BarrierActive flag, see
	Abilities/Barrier/_Construct); only the owner plays the clip, which replicates through
	its Animator. Nothing depends on it loading.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Client.Util.Animations)

-- The legacy "BarrierCross" clip. It has no AnimationConfig entry, so it is not preloaded.
local CROSS_ANIMATION = "rbxassetid://98292653654665"
local FADE = 0.1

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local animator = Animations.FindAnimator(character)
	if not animator then
		return noop
	end

	local track = Animations.Get(animator, CROSS_ANIMATION)
	track:Play(FADE, 1, 1)

	return function()
		track:Stop(FADE)
	end
end
