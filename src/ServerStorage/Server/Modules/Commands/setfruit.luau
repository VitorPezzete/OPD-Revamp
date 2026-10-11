-- Legacy Spec / Cultist "Fruit" and "Fruit2": testers and staff set their own fruit.
return {
	Name = "setfruit",
	Description = "Sets one of your own devil fruits with full affinities (`none` removes it).",
	Group = "Tester",
	Args = {
		{ Type = "integer", Name = "Slot", Description = "1 or 2" },
		{ Type = "string", Name = "Fruit", Description = "Fruit name, or none" },
	},
}
