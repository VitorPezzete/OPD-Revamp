--!strict
--[[
	Paw fruit - the paw pads. Whoever owns the fruit carries a small pink pad on each palm
	for as long as it does (the source Customize script welded one to both arms every time
	the character was dressed). Purely cosmetic: the replicated "PawPads" status is all the
	server keeps, and every client draws the pads (Effects.Status.PawPads).
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

local STATUS = "PawPads"

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	_data: PlayerData.PlayerData,
	_fruitSlot: number
): () -> ()
	entity:SetStatus(STATUS, true, nil, true)

	return function()
		entity:ClearStatus(STATUS)
	end
end
