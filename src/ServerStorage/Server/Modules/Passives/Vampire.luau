--!strict
--[[
	Vampire fruit - passive.

	- By night the vampire has 125% max health (legacy HealthV2). VampireShared asks
	  TimeService (day is after 06:00 and before 18:00) and tells us when it flips.
	- Killing a player raises a bat; every other kill made by a player leaves a soul.
	  Both hooks are global and live in VampireShared (started here, once).
	- The replicated VampirePassive status lets the vampire's own client show what only
	  vampires see (souls).

	The cleanup also removes the bats and the attack mode: they belong to this
	character. The bite marks it left stay on their victims until they die, as in legacy
	(see VampireShared).
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local VampireShared = require(ServerStorage.Server.Modules.Abilities.Vampire.VampireShared)

local NIGHT_MODIFIER = "VampireNight"
local NIGHT_HEALTH = 1.25

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	VampireShared.Start()

	local fruits = data.Data.DevilFruits
	VampireShared.Register(entity, if fruitSlot == 1 then fruits.Slot1.Color else fruits.Slot2.Color)

	local function applyTime(isDay: boolean)
		entity:SetMaxHealthModifier(NIGHT_MODIFIER, if isDay then nil else NIGHT_HEALTH)
	end
	applyTime(VampireShared.IsDay())
	local connection = VampireShared.DayChanged:Connect(applyTime)

	entity:SetStatus(VampireShared.Status.Passive, true, nil, true)

	return function()
		connection:Disconnect()
		entity:SetMaxHealthModifier(NIGHT_MODIFIER, nil)
		entity:ClearStatus(VampireShared.Status.Passive)
		VampireShared.Unregister(entity)
	end
end
