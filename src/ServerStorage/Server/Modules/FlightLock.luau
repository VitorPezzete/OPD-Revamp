--!strict
--[[
	The legacy "flight disabler", for every fruit at once.

	Legacy: each character had one counter (`FDP`, FDPModule:AddFDP(3) = +1 for 3 s). The
	LocalScript of every fruit called `AbilityActivated()` (which raised it) from its
	PowerN functions, and the LocalScript of every fruit with a flight watched it: while
	it was not zero the flight landed and refused to take off. The counter belonged to
	the character, not to the fruit, so a power of one fruit grounded the flight of the
	other.

	Here: AbilityService raises the entity status AbilityConfig.Status.FlightLock for
	AbilityConfig.FlightLockSeconds on the key events listed below and lands every
	ability whose class sets `Flight = true`; those classes refuse to take off while the
	status is up (Ability.IsFlightBlocked). Raising it again restarts the 3 s, which is
	what the counter amounted to.

	WHEN an ability raises it is per ability, read from where its legacy PowerN function
	called AbilityActivated():
		"Press"    inside `if key == Begin` (the default: abilities not listed here)
		"Release"  inside `if key == End` (powers that fire when the key is let go)
		"Both"     before the key state was looked at, or in both branches
		"None"     never
	The legacy call sat before the remote was fired, so a press the server then refused
	(cooldown) had raised the counter all the same: AbilityService raises it before the
	ability's own CanBegin for the same reason.

	Flights (`Flight = true`) never raise it, whatever this table says. Abilities whose
	legacy SERVER script raised the counter itself (Slash Frenzy every round, Bomb Full
	Body while charging) call AbilityService:RaiseFlightLock on top of their entry here.
]]
export type Mode = "Press" | "Release" | "Both" | "None"

local FlightLock = {}

-- [fruit][ability name] = when its key raises the lock. Line numbers are the
-- AbilityActivated() calls in legacy/Workspace/AA/ToPlayerCharacter/Powers/<Fruit>.client.luau.
local MODES: { [string]: { [string]: Mode } } = {
	Alice = {
		-- 84, 106, 116, 147, 156: `if Key == End then AbilityActivated()`.
		["Cards of Fate"] = "Release",
		["Tea Party"] = "Release",
		["Wonderland Delirium"] = "Release",
		["Looking Glass"] = "Release",
		["Wonderland"] = "Release",
	},
	Barrier = {
		["Prison"] = "Release", -- 153
	},
	Blood = {
		-- 85, 100, 110, 202
		["Blood Hemomancy"] = "Release",
		["Blood Convergence"] = "Release",
		["Blood Supernova"] = "Release",
		["Blood Concentrate"] = "Release",
	},
	Bomb = {
		-- 80, 301, 761: before the key check.
		["Bomb Punch"] = "Both",
		["Bomb Boost"] = "Both",
		["Bomb Wave"] = "Both",
		-- 929: commented out. The server raised it instead (StartCharge.server 325-338).
		["Full Body"] = "None",
	},
	Candy = {
		["Jawbreaker"] = "Both", -- 132
	},
	Chilly = {
		["Freezing Punch"] = "Both", -- 154
		["Ice Wave"] = "Both", -- 432
	},
	Chop = {
		-- 118, 130, 142
		["Chop Choke"] = "Both",
		["Chop Pursuit"] = "Both",
		["Chop Car"] = "Both",
	},
	Clone = {
		-- 163, 197, 209
		["Clone Rush"] = "Both",
		["Dapper Duplication"] = "Both",
		["Copycat"] = "Both",
	},
	Dark = {
		["Dark Charge"] = "Both", -- 80
		["Dark Star"] = "Both", -- 195
	},
	Diamond = {
		["Diamond Cluster"] = "Both", -- 218
	},
	Door = {
		-- 83, 98, 108
		["Door Strike"] = "Release",
		["Escape Door"] = "Release",
		["Crushing Gate"] = "Release",
	},
	Flare = {
		-- 241 + 327, 415 + 523, 630 + 709: on Begin and on End.
		["Fire Fist"] = "Both",
		["Flame Pillar"] = "Both",
		["Flame Emperor"] = "Both",
	},
	Float = {
		-- AbilityActivated is defined (95) and never called.
		["Float"] = "None",
		["Ascend"] = "None",
	},
	Gas = {
		["Gastille"] = "Both", -- 292, 346, 377
	},
	Gravity = {
		["Gravity Repel"] = "Release", -- 380
		["Crushing Force"] = "Both", -- 459, 503
		["Meteor Shower"] = "Release", -- 524
		["Meteor Crash"] = "Release", -- 663
	},
	Gum = {
		-- 132, 187, 242, 670, 862
		["Pistol"] = "Both",
		["Bazooka"] = "Both",
		["Gatling"] = "Both",
		["Gum Rocket"] = "Both",
		["2nd Gear"] = "Both",
	},
	Hollow = {
		["Negative Hollow"] = "Both", -- 241
		["Mini-Hollow"] = "Both", -- 320
	},
	Light = {
		-- 213, 466, 687, 763
		["Light Blast"] = "Both",
		["Yata Mirror"] = "Both",
		["Light Beam"] = "Both",
		["Sacred Jewels"] = "Both",
	},
	Love = {
		-- 111, 199, 263, 467, 671
		["Glare"] = "Both",
		["Pistol Kiss"] = "Both",
		["Beam"] = "Both",
		["Slave Arrow"] = "Both",
		["Arrow Storm"] = "Both",
	},
	Luck = {
		["Slot Machine"] = "None", -- Power2 (202-210) never calls it.
	},
	Magma = {
		["Great Eruption"] = "Both", -- 91
	},
	Ope = {
		-- 175, 221, 246, 277
		["Room"] = "Both",
		["Scalpel"] = "Both",
		["Shambles"] = "Both",
		["Severance"] = "Both",
	},
	Order = {
		["Command Strike"] = "Both", -- 144
	},
	-- The source place raised the lock on press and on release for all four powers.
	Paw = {
		["Pressure Bubble"] = "Both",
		["Pad Cannon"] = "Both",
		["Spatial Repulsion"] = "Both",
		["Ursus Shock"] = "Both",
	},
	Phoenix = {
		["Phoenix Burst"] = "Both", -- 1194, 1252, 1287
		["Phoenix Pulse"] = "Both", -- 1326
	},
	Plasma = {
		["Plasma Cannon"] = "Both", -- 290
	},
	Quake = {
		-- 123, 286, 440, 616
		["Quake Punch"] = "Both",
		["Tsunami"] = "Both",
		["Quake Stomp"] = "Both",
		["Seismic Wave"] = "Both",
	},
	Return = {
		-- 118, 141, 196
		["Return Self"] = "Both",
		["Return Other"] = "Both",
		["Restore All"] = "Both",
	},
	Rumble = {
		["El Thor"] = "Both", -- 145
		["Lightning Blitz"] = "Both", -- 349
	},
	Sand = {
		["Sandstorm"] = "Both", -- 241, 286, 325
	},
	Slash = {
		["Slash Dismantle"] = "Both", -- 313
		["Slash Cleave"] = "Both", -- 372
	},
	Smoke = {
		["White Out"] = "None", -- 299: commented out.
		["White Fist"] = "None", -- Power3 (313-327) never calls it.
		["Whiteout Burst"] = "Both", -- 346, 361
	},
	Snow = {
		["Snow Pellet"] = "Both", -- 214, 283, 329
		["Snow Ring"] = "Both", -- 620, 627
	},
	String = {
		-- 91, 111, 188, 365, 542
		["Tether"] = "Both",
		["Flapping Thread"] = "Both",
		["Sky String"] = "Both",
		["Bird Cage"] = "Both",
		["God Thread"] = "Both",
	},
	Swim = {
		["Dive"] = "Both", -- 86
	},
	Vampire = {
		-- 128 + 135, 205, 284, 353
		["Sanguine Vampiris"] = "Both",
		["Hypnosis"] = "Both",
		["Necromancy"] = "Both",
		["Bat Swarm"] = "Both",
		["Transform"] = "None", -- Power6 never calls it.
	},
	Venom = {
		-- 103, 187, 391
		["Poison Breath"] = "Both",
		["Venom Hydra"] = "Both",
		["Chloro Ball"] = "Both",
	},
}

function FlightLock.GetMode(fruitName: string, abilityName: string): Mode
	local fruit = MODES[fruitName]
	return (fruit and fruit[abilityName]) or "Press"
end

return FlightLock
