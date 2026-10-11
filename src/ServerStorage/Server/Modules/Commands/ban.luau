-- Legacy Spec "Ban" / "Global Ban" (both wrote the same DataStore flag).
return {
	Name = "ban",
	Description = "Bans a user from the whole game, online or not.",
	Group = "Mod",
	Args = {
		{ Type = "playerId", Name = "Player", Description = "Name or #userId" },
		{ Type = "string", Name = "Reason", Description = "Shown to the player (filtered by Roblox)" },
		{ Type = "duration", Name = "Duration", Description = "e.g. 7d, 12h; permanent when omitted", Optional = true },
	},
}
