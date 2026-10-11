--!strict
--[[
	Phoenix fruit - passive: much faster health regeneration and the egg that replaces
	death. Both are described in Abilities.Phoenix._Shared, which holds the state because
	DamageModifiers.PhoenixEgg needs it as well.

	Phoenix is not a logia: the legacy Logia script does not list it, so no melee / sword
	immunity is granted (the Phoenix branch of LogiaModule could never run).

	Gum's 2nd Gear stopped regeneration for everyone but Phoenix owners. Gum is not
	ported yet: when it is, it must leave an entity with the "PhoenixPassive" status
	alone instead of overwriting "RegenMultiplier".
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local PhoenixShared = require(ServerStorage.Server.Modules.Abilities.Phoenix._Shared)

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	return PhoenixShared.Start(entity, data, fruitSlot)
end
