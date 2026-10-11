-- Legacy Spec "Join Name": join the server a user is in, private code servers included.
return {
	Name = "follow",
	Description = "Teleports you to the server a user is playing in.",
	Group = "Mod",
	Args = {
		{ Type = "playerId", Name = "Player", Description = "Name or #userId" },
	},
}
