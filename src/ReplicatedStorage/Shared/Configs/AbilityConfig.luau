--!strict
return table.freeze({
	-- Minimum time between two inputs of the same ability, unless the ability overrides it.
	DefaultDebounce = 0.25,
	-- Aim points further than this from the caster are brought back to it (same direction),
	-- unless the ability reaches further (Ability.MaxAimDistance).
	MaxAimDistance = 1000,
	-- The furthest any ability may ask for (Ability.MaxAimDistance); nothing beyond is accepted.
	HardMaxAimDistance = 5000,
	-- One-shot effects are only sent to players within this distance of their origin.
	EffectRadius = 400,
	-- Per player budget for ability inputs: { burst, refill per second }. Held abilities
	-- stream their aim as phase 3 at up to 10 per second, and two can be held at once.
	-- Releases have a budget of their own (AbilityService), so they are never starved.
	InputBudget = table.freeze({ 30, 24 }),
	-- Seconds every flight of a character stays grounded after one of its powers raised the
	-- flight lock (legacy FDPModule:AddFDP(3)). See Server.Modules.FlightLock.
	FlightLockSeconds = 3,

	-- Status names shared by server logic and client effects. Replicated as attributes.
	Status = table.freeze({
		-- Fruit powers are sealed (seastone, water, Hobby, ...).
		AbilitiesDisabled = "AbilitiesDisabled",
		Invisible = "Invisible",
		SlipRushing = "SlipRushing",
		-- Server only: flights land and may not take off (Server.Modules.FlightLock).
		FlightLock = "FlightLock",
	}),
})
