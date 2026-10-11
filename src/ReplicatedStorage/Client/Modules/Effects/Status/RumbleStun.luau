--!strict
--[[
	Rumble fruit - electrocuted by El Thor: the victim shakes for the 1.25 s the server
	keeps the status (the root and the ability interruption are server side).

	As in the legacy game the electrocution clip is all there is to see: no sparks were
	drawn on the victim. It is played by the victim's own client only: its Animator
	replicates it to everyone else. The clip id comes from the legacy RumbleStun control
	script; it is not in AnimationConfig (so it is not preloaded) because a copy of the
	place may have no permission to load it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Client.Util.Animations)

local ELECTROCUTION_ANIMATION = "rbxassetid://83968454437614"

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return noop
	end

	local track = Animations.Get(animator, ELECTROCUTION_ANIMATION)
	track:Play()
	return function()
		track:Stop()
	end
end
