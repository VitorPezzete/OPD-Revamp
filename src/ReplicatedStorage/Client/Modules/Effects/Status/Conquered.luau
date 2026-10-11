--!strict
--[[
	Brought down by Conqueror's Haki: the character kneels for as long as the status is
	on (the stun itself is the server's).
	Value: the stage of the burst that did it.

	A player's kneel is played by its own client only (its Animator replicates it to
	everyone else); an NPC's is played by every client that sees it. A victim of a stage 3
	burst also sees the world through the technique's screen tint until it gets up.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimationConfig = require(ReplicatedStorage.Shared.Configs.AnimationConfig)
local Animations = require(ReplicatedStorage.Client.Util.Animations)
local ConquerorFx = require(script.Parent.Parent.Util.ConquerorFx)

local TINT_STAGE = 3
local FADE = 0.2

return function(character: Model, value: any, isLocal: boolean): () -> ()
	local track: AnimationTrack? = nil
	local clips = (AnimationConfig :: any).Conqueror
	local kneel = clips and clips.ConqueredKneel
	local animator = Animations.FindAnimator(character)
	local isPlayer = Players:GetPlayerFromCharacter(character) ~= nil
	if animator and type(kneel) == "string" and (isLocal or not isPlayer) then
		local playing = Animations.Get(animator, kneel)
		playing.Priority = Enum.AnimationPriority.Action
		playing:Play(FADE)
		track = playing
	end

	local tint = if isLocal and value == TINT_STAGE then ConquerorFx.Tint() else nil

	return function()
		if track then
			track:Stop(FADE)
		end
		if tint then
			tint:Destroy()
		end
	end
end
