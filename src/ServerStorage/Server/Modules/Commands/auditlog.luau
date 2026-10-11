-- What staff did on this server. New: the legacy game only posted to webhooks.
return {
	Name = "auditlog",
	Description = "Shows the latest privileged actions on this server, newest first.",
	Group = "Mod",
	Args = {
		{ Type = "positiveInteger", Name = "Lines", Description = "How many entries", Default = 20 },
	},
}
