-- Legacy Spec "Unban" / "Global Unban".
return {
	Name = "unban",
	Description = "Lifts a ban (new or legacy).",
	Group = "Mod",
	Args = {
		{ Type = "playerId", Name = "Player", Description = "Name or #userId" },
	},
}
