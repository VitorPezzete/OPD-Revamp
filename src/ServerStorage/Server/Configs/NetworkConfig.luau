--!strict
return table.freeze({
	-- Shared by every remote call a player makes (token bucket).
	GlobalBurst = 60,
	GlobalRefillPerSecond = 30,

	-- Per-action budgets: { burst, refill per second }.
	Actions = table.freeze({
		Spawn = { 1, 0.2 },
		EquipWeapon = { 4, 2 },
	}),

	-- How long a player is protected (and unable to deal damage) after spawning.
	SpawnProtectionSeconds = 4,
})
