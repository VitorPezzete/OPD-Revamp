--!strict
--[[
	Hollow fruit - Fade (toggle): makes the projected ghost body invisible, or visible
	again. Only usable while Projection is on.

	A faded ghost is harmless: it does not make the characters it touches Negative
	(Projection checks the "HollowFaded" status). The fade itself is drawn by
	Effects.Status.HollowProjecting, which owns the ghost model.

	The state belongs to the ghost, so Projection clears it when the ghost goes away;
	it is a status rather than a field because sibling abilities share nothing else.
	The legacy tweened the Transparency of every ghost part on the server.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local HollowNegative = require(script.Parent.HollowNegative)

local Fade = Ability.extend()

function Fade:CanBegin(): boolean
	return self.Entity:HasStatus(HollowNegative.ProjectingStatus)
end

function Fade:OnBegin()
	local entity = self.Entity
	local faded = not entity:HasStatus(HollowNegative.FadedStatus)
	entity:SetStatus(HollowNegative.FadedStatus, faded, nil, true)
end

function Fade:OnInterrupt()
	self.Entity:ClearStatus(HollowNegative.FadedStatus)
end

return Fade
