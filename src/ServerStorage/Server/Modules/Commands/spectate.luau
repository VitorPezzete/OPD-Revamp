-- Legacy Spec list (clicking a name pointed the camera at that player).
return {
	Name = "spectate",
	Aliases = { "spec" },
	Description = "Watches a player; without a name, goes back to your character.",
	Group = "Mod",
	Args = {
		{ Type = "player", Name = "Player", Description = "Who to watch", Optional = true },
	},
}
