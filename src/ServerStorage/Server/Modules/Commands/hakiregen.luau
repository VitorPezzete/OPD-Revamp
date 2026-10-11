-- Legacy Commands "Haki Regen" (self, mods) and "Regen Server Haki" (everyone, owners).
return {
	Name = "hakiregen",
	Description = "Refills your haki bar; `hakiregen true` refills everyone's (owners).",
	Group = "Mod",
	Args = {
		{ Type = "boolean", Name = "Everyone", Description = "Refill the whole server (owners only)", Default = false },
	},
}
