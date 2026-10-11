--!strict
--[[
	Alice fruit passive.

	The fruit's always-on effect, the doubled haki bar, is applied by HakiService. What
	is left for this file is the other half of a passive's contract: when the fruit (or
	the character) goes away, remove the state its abilities leave on the owner on
	purpose - the tea drunk last, the spare Cards of Fate throws and the Max tea's +20%
	max health (the legacy HealthV2 "TeaMax" branch), none of which a stun may take away.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Shared = require(ServerStorage.Server.Modules.Abilities.Alice._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

return function(entity: CharacterEntity): () -> ()
	return function()
		entity:ClearStatus(Shared.TeaStatus)
		entity:ClearStatus(Shared.CardChargesStatus)
		Shared.ClearTeaMax(entity)
	end
end
