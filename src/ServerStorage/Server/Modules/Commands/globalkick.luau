-- Legacy Commands "Global Kick".
return {
	Name = "globalkick",
	Description = "Kicks a user from whichever server they are in.",
	Group = "Mod",
	Args = {
		{ Type = "playerId", Name = "Player", Description = "Name or #userId" },
	},
}
