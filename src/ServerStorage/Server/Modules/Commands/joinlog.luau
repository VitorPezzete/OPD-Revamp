-- Legacy Commands "Join/Leave Log" (the server wrote it straight into the mod's PlayerGui).
return {
	Name = "joinlog",
	Description = "Shows who joined and left this server, newest first.",
	Group = "Mod",
	Args = {
		{ Type = "positiveInteger", Name = "Lines", Description = "How many entries", Default = 30 },
	},
}
