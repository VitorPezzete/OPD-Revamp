--!strict
return table.freeze({
	-- OrderedDataStore of the legacy game: key = user id, value = bounty.
	StoreName = "GlobalBounty",
	Size = 100,

	-- The service runs one loop. Every tick it re-ranks with the live bounties of this server.
	TickInterval = 30,
	-- Every this many ticks it reads the global top from the store (one request per server).
	ReadEveryTicks = 6,
	-- Every this many ticks it saves the bounty of the players whose bounty changed.
	WriteEveryTicks = 10,
	-- Pause between two saves of the same pass, to stay far from the write budget.
	WriteSpacing = 1,
})
