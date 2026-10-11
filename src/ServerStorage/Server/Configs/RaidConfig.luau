--!strict
--[[
	Raid lobbies of the Legendary Hero (legacy LegendaryHeroServer).

	The raids themselves (waves, bosses, rewards) run in another place of the experience:
	this place only gathers the party and teleports it to a reserved server of PlaceId.
	Set PlaceId to 0 to disable raids (the lobby then explains itself and sends everyone back).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)

return table.freeze({
	PlaceId = PlaceConfig.Places.Raid,
	-- Where a raid sends its players back to.
	ReturnPlaceId = PlaceConfig.Places.Main,

	-- MemoryStore map in which this place leaves a ticket for the reserved server it
	-- sends a party to (key: the server's PrivateServerId). The raid place reads its own
	-- ticket instead of believing the teleport data, which travels through the clients.
	TicketMap = "RaidTickets",
	TicketLifetime = 600,

	-- Owner included.
	PartySize = 4,
	-- Seconds before the party leaves on its own; the owner can leave earlier.
	Countdown = 60,
	InviteLifetime = 10,
	-- Seconds before a leader can invite the same player again, accepted or not.
	InviteRepeat = 30,
	-- A member whose own teleport fails is sent once more after TeleportRetry seconds;
	-- one that is still in the waiting room DepartureTimeout seconds after the party
	-- left is put back on the ground.
	TeleportRetry = 3,
	DepartureTimeout = 30,

	-- Where the party waits (far above the map, characters are anchored there) and where
	-- a member lands when leaving the lobby (next to the Legendary Hero).
	LobbyCFrame = CFrame.new(238, 197554.234, -10836),
	LobbySpacing = 5,
	ReturnCFrame = CFrame.new(-1281.5, 216, -1353),

	-- "Type" of the teleport data read by the raid place, per quest name.
	TeleportType = table.freeze({ MarineRaid = "Marine", Endless = "Endless" }),

	-- Data keys under Bosses.<key> written by RaidService:RecordResult, per quest name.
	DataKey = table.freeze({ MarineRaid = "MarineRaid", Endless = "EndlessRaid" }),
})
