-- Legacy Commands "Set" / "Add" (Data_Set, Data_Add), for players in this server.
return {
	Name = "data",
	Description = "Sets or adds to one saved value of an online player, e.g. data Bob add Economy.Beri 5000",
	Group = "Owner",
	Args = {
		{ Type = "player", Name = "Player", Description = "Whose data" },
		{ Type = "string", Name = "Mode", Description = "set or add" },
		{ Type = "string", Name = "Path", Description = "Dot path, e.g. Skills.Melee.Level" },
		{ Type = "string", Name = "Value", Description = "Number, true/false or text" },
	},
}
