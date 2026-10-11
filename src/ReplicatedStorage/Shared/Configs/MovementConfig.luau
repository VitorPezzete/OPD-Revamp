--!strict
--[[
	Numbers of the two movement techniques every character has (legacy Dash / Shave
	scripts and the Level values stored under their remotes), and of floating on the sea.

	Shared because the owning client moves its own character (dash push, buoyancy) and
	gates the request locally; the server decides whether a request is accepted.
]]
local MovementConfig = {}

MovementConfig.Dash = table.freeze({
	-- Melee level needed (legacy Dash.Level).
	Requirement = 50,
	-- Seconds the push lasts.
	Duration = 0.3,
	-- The dash animation is stopped after this long, whatever its length.
	AnimationSeconds = 0.5,
	-- Push speed in studs per second = clamp(Base + melee * PerLevel, Min, Max), floored.
	Base = 70,
	PerLevel = 0.14,
	Min = 30,
	Max = 132,
	-- Stuck in candy or snow: a tenth of the normal speed, with a lower floor.
	SlowedScale = 0.1,
	SlowedMin = 10,
	-- Float fruit users: clamp(Base + melee * PerLevel * melee affinity, Min, Max), floored.
	Float = table.freeze({ Fruit = "Float", Base = 87.5, PerLevel = 0.175, Min = 60, Max = 350 }),
	-- Cooldown in seconds = Cooldown - melee * CooldownPerLevel * (1 + BuffDash / 100).
	Cooldown = 3,
	CooldownPerLevel = 0.003,
	PerkScale = 0.01,
	-- Replicated (true) for Duration seconds: every client plays the dash sound from it.
	Status = "Dashing",
})

MovementConfig.Shave = table.freeze({
	-- Melee level needed (legacy Shave.Level).
	Requirement = 200,
	-- The character lands this far above the aimed point.
	LandingHeight = 2,
	-- Reach in studs = clamp(melee * PerLevel, Min, Max).
	PerLevel = 0.25,
	Min = 50,
	Max = 125,
	Cooldown = 1.3,
	-- Each BuffShave point shortens the cooldown by this fraction.
	PerkScale = 0.005,
	-- Rumble users: reach = clamp(melee * PerLevel * melee affinity, Min, Max),
	-- cooldown = Cooldown - CooldownPerAffinity * melee affinity.
	Rumble = table.freeze({
		Fruit = "Rumble",
		PerLevel = 0.45,
		Min = 90,
		Max = 180,
		Cooldown = 1.5,
		CooldownPerAffinity = 0.5,
	}),
	-- Gum users in 2nd Gear: reach * affinity ^ affinity, and each shave costs health.
	Gum = table.freeze({ Fruit = "Gum", Status = "Gum2nd", HealthCost = 100 }),
	-- Snow users inside their own globe reach anywhere in it and leave a snow statue behind.
	Snow = table.freeze({ Fruit = "Snow", Status = "SnowGlobe" }),
	-- One-shot effect name.
	Effect = "Shave",
})

-- Statuses that refuse both techniques while they are on the character.
MovementConfig.BlockingStatuses = table.freeze({
	"Stunned",
	"BombSelfDestruct",
	"SandInSandstorm",
	"StringInsideCage",
	-- NoMovementStatuses, repeated here (this list is what Dash and Shave read).
	"SlashFrenzy",
	"DoughMochiCovered",
	"DoughTorqueMochi",
	"DoughTorqueCaught",
})

-- The legacy NoMovement flag: the character may walk, but Dash, Shave and the take-off of
-- the flights that checked the flag (Ability.IsFlightBlocked) are refused. Replicated
-- statuses, so the owner's client can gate its own request. Slash Frenzy set it for its
-- whole length (DF Slash.server 562-605). Hollow's Projection set it too, but that one
-- roots the character here, which already refuses all three.
MovementConfig.NoMovementStatuses = table.freeze({
	"SlashFrenzy",
	-- Dough: stuck in the mochi wasteland, spinning the Torque Mochi, caught by one.
	"DoughMochiCovered",
	"DoughTorqueMochi",
	"DoughTorqueCaught",
})

-- Debuffs that refuse Shave and shorten Dash (sticky candy, deep snow).
MovementConfig.SlowingStatuses = table.freeze({ "CandyTouched", "SnowTouched" })

MovementConfig.Water = table.freeze({
	-- Seconds between two water hits on a fruit user, and the fraction of max health each takes.
	DamageInterval = 0.23,
	DamageFraction = 0.1,
	-- How far above the sea surface still counts as "in the water".
	Margin = 0.1,
	-- Tag of the damage request, read by DamageModifiers.WaterTrueDamage.
	Tag = "Water",
	-- Buoyancy of the local character: checked this often, jumping out pushes up for JumpSeconds.
	FloatInterval = 0.1,
	JumpSpeed = 50,
	JumpSeconds = 0.1,
	-- A character carrying a status ending in one of these is flying and is left alone.
	FlightSuffixes = table.freeze({ "Flying", "Floating", "Levitating" }),
})

return table.freeze(MovementConfig)
