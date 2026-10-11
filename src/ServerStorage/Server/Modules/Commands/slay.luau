-- Legacy Spec "Slay" (it reloaded the character).
return {
	Name = "slay",
	Description = "Kills a player's character so it respawns.",
	Group = "Mod",
	Args = {
		{ Type = "player", Name = "Player", Description = "Who to respawn" },
	},
}
