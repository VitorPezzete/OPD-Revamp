--!strict
--[[
	Gravity fruit - a character flattened by Crushing Force. The server times the status
	(value: the attacker's fruit color string, unused: the legacy game drew nothing on
	the victim).

	Victim only: the body goes limp (PlatformStand) until the status ends. The legacy
	server set PlatformStand itself; a player's humanoid state belongs to its own
	client, so it is done here. NPCs are only stunned by the server.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Limp = require(ReplicatedStorage.Client.Modules.Effects.Util.Limp)

local function noop() end

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end
	local foundHumanoid = character:FindFirstChildOfClass("Humanoid")
	if not foundHumanoid then
		return noop
	end
	-- Counted: another status may hold the character limp at the same time.
	return Limp.hold(foundHumanoid)
end
