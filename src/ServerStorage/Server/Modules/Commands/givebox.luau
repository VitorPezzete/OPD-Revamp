-- Legacy Commands box buttons and "Compass": a devil fruit box or a compass in a backpack.
return {
	Name = "givebox",
	Description = "Puts a devil fruit box or a compass in a player's backpack (quote names with spaces).",
	Group = "Owner",
	Args = {
		{ Type = "string", Name = "Item", Description = 'Box or compass name, e.g. "Rare Box", "Golden Compass"' },
		{ Type = "player", Name = "Player", Description = "Receiver (you when omitted)", Optional = true },
	},
}
