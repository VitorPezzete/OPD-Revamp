--!strict
--[[
	Server-only part of the player list: who is left out of it.

	The legacy list kept these ids in the LocalScript of every client. They are staff who
	asked not to be listed; only owners see them. (This is cosmetic: the engine still
	tells every client who is in the server.)
]]
return table.freeze({
	HiddenUserIds = table.freeze({
		2261590335,
		630398541,
		389403845,
		7124931877,
	}),
})
