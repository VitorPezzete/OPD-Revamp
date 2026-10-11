--!strict
--[[
	String fruit - Release: cuts every string made with Tether - the tied ones and the
	one still in the hand - freeing leashed characters and lifting the "no new string
	while someone is caught" lock.

	The strings belong to the sibling Tether ability, which keeps them in the
	non-replicated "StringTetherState" status of the user ({ Ropes, Clear }).
	0.25 s debounce, as in the legacy game.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATE_STATUS = "StringTetherState"

local Release = Ability.extend()

function Release:OnBegin()
	local state = self.Entity:GetStatus(STATE_STATUS)
	if state then
		state.Clear()
	end
end

return Release
