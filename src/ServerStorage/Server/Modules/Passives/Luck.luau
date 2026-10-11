--!strict
--[[
	Luck fruit passive: owns the luck gauge.

	The gauge ("LuckPercent", 0-100) exists for as long as the fruit is owned, starts
	empty on every new character (the legacy value lived in the character's script) and
	is replicated so Effects.Status.LuckPercent can draw the bar. Losing the fruit
	removes it together with the timed luck states the abilities may have left.

	The fruit's other always-on effects are elsewhere:
	- 15% chance to nullify a hit   DamageModifiers/LuckNullify
	- immunity to damage over time  DamageModifiers/LuckDotImmunity
	- bonus Beri on kills           RewardService
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Shared = require(ServerStorage.Server.Modules.Abilities.Luck._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

return function(entity: CharacterEntity): () -> ()
	Shared.Set(entity, 0)

	return function()
		entity:ClearStatus(Shared.PercentStatus)
		entity:ClearStatus(Shared.JackpotStatus)
		entity:ClearStatus(Shared.MomentStatus)
	end
end
