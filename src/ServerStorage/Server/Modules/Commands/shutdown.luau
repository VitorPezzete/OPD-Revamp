-- Legacy "Shutdown Servers" countdown, on demand.
return {
	Name = "shutdown",
	Description = "Closes this server after a countdown. Rejoin sends players to fresh servers instead of kicking.",
	Group = "Owner",
	Args = {
		{ Type = "nonNegativeInteger", Name = "Seconds", Description = "Countdown (max 3600)", Default = 300 },
		{ Type = "boolean", Name = "Rejoin", Description = "Soft shutdown: teleport players to new servers", Default = false },
	},
}
