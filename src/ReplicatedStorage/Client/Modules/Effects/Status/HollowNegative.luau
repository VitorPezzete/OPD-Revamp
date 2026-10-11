--!strict
--[[
	Hollow fruit - Negative: the victim slumps in the looping "Negative" pose for as long
	as the status is set. The stun itself (root, abilities interrupted) is the server's.

	The legacy Negative clip is the same asset as the Hollow "Projection" clip, which is
	the only place AnimationConfig lists it.

	An animation only replicates from whoever simulates the character, so it is played
	by the victim's own client; for NPC enemies (simulated by the server, which plays
	no visuals) every client plays it locally.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)

local FADE = 0.2

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal and Players:GetPlayerFromCharacter(character) then
		return noop
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return noop
	end

	local track = Animations.Get(animator, AnimationConfig.Fruits.Hollow.Projection)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Action
	track:Play(FADE)

	return function()
		track:Stop(FADE)
	end
end
