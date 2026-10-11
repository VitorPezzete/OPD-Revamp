-- Legacy Commands "Spawn" (Data_Spawn): a fruit item with chosen affinity scores.
return {
	Name = "givefruit",
	Description = "Puts a devil fruit item in a player's backpack. Scores are 0-10; random when omitted.",
	Group = "Owner",
	Args = {
		{ Type = "string", Name = "Fruit", Description = "Fruit name" },
		{ Type = "player", Name = "Player", Description = "Receiver (you when omitted)", Optional = true },
		{ Type = "integer", Name = "Defense", Description = "0-10", Optional = true },
		{ Type = "integer", Name = "Melee", Description = "0-10", Optional = true },
		{ Type = "integer", Name = "Sniper", Description = "0-10", Optional = true },
		{ Type = "integer", Name = "Sword", Description = "0-10", Optional = true },
	},
}
