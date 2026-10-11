--!strict
--[[
	Ope fruit passive: every kill gives Room stamina back,
	250 * defense affinity * (defense level / 500), up to the maximum.

	The legacy fruit script listened to RewardModule.Killed for this. Stamina itself
	lives in Abilities/Ope/OpeRoom (shared with the four abilities).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local OpeRoom = require(ServerStorage.Server.Modules.Abilities.Ope.OpeRoom)

type CharacterEntity = CharacterEntity.CharacterEntity

local STAMINA_PER_KILL = 250
local LEVEL_SCALE = 500

return function(entity: CharacterEntity, _player: Player, data: PlayerData.PlayerData, fruitSlot: number): () -> ()
	local combatService = Knit.GetService("CombatService")

	local connection = combatService.Killed:Connect(function(_target: CharacterEntity, attacker: CharacterEntity?)
		if attacker ~= entity then
			return
		end
		local affinities = data.Data.Affinities
		local affinity = if fruitSlot == 1 then affinities.DF1.Defense else affinities.DF2.Defense
		OpeRoom.AddStamina(entity, STAMINA_PER_KILL * affinity * (data.Data.Skills.Defense.Level / LEVEL_SCALE))
	end)

	return function()
		connection:Disconnect()
	end
end
