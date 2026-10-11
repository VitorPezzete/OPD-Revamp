--!strict
--[[
	Slash fruit - bookkeeping for the Slash Frenzy cooldown.

	The legacy fruit script started the 120 s cooldown when it was created (character
	spawn) and listened to RewardModule.Killed: every PLAYER killed since the last Frenzy
	took 10 * defense affinity seconds off it. The ability object only exists from the
	first press on, so both facts are kept here, in two non-replicated statuses read by
	Abilities/Slash/Slash Frenzy:

	- SlashFrenzyBorn:  os.clock() when this passive started;
	- SlashFrenzyKills: players killed since then, reset to 0 by each Frenzy.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type CharacterEntity = CharacterEntity.CharacterEntity

-- Same names as in Abilities/Slash/_Shared.
local BORN_STATUS = "SlashFrenzyBorn"
local KILLS_STATUS = "SlashFrenzyKills"

return function(entity: CharacterEntity, _player: Player, _data: PlayerData.PlayerData, _fruitSlot: number): () -> ()
	entity:SetStatus(BORN_STATUS, os.clock())
	entity:SetStatus(KILLS_STATUS, 0)

	local combatService = Knit.GetService("CombatService")
	local connection = combatService.Killed:Connect(function(target: CharacterEntity, attacker: CharacterEntity?)
		if attacker == entity and target.Player then
			local kills = entity:GetStatus(KILLS_STATUS)
			entity:SetStatus(KILLS_STATUS, (if type(kills) == "number" then kills else 0) + 1)
		end
	end)

	return function()
		connection:Disconnect()
		entity:ClearStatus(BORN_STATUS)
		entity:ClearStatus(KILLS_STATUS)
	end
end
