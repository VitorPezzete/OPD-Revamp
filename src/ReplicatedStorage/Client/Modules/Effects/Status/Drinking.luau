--!strict
--[[
	Drinking animation while ConsumableService holds the "Drinking" status (2 seconds).
	Only the owner plays it: tracks started on a character's own Animator replicate to
	everyone else, so the other clients have nothing to do.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

-- The legacy drinks slowed the animation to fill the 2 seconds.
local SPEED = 0.5
local FADE = 0.1

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	local animationId = (AnimationConfig :: any).Drinking
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not isLocal or not animator or type(animationId) ~= "string" then
		return noop
	end

	local track = Animations.Get(animator, animationId)
	track:Play(FADE)
	track:AdjustSpeed(SPEED)

	return function()
		track:Stop(FADE)
	end
end
