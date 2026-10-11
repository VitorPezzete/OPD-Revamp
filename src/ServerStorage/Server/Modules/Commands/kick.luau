-- Legacy Spec "Kick".
return {
	Name = "kick",
	Description = "Kicks a player from this server.",
	Group = "Mod",
	Args = {
		{ Type = "player", Name = "Player", Description = "Who to kick" },
		{ Type = "string", Name = "Reason", Description = "Kept in the audit log", Optional = true },
	},
}
