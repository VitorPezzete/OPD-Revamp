-- Legacy cross-server announcement (the Announcement banner).
return {
	Name = "announce",
	Description = "Shows a banner to every server of the game.",
	Group = "Owner",
	Args = {
		{ Type = "string", Name = "Text", Description = "The announcement" },
	},
}
