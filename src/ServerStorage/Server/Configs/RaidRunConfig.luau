--!strict
--[[
	The raids themselves, as played in the raid place (RaidRunService): waves, enemies,
	bosses and what they pay. The lobby in the main place is RaidConfig.

	Legacy sources (place "Raids"): ServerScriptService.Raids.RaidsHandler and JoinRaid,
	ServerScriptService.Script (server lifetime), etc.Unlock.BossDrops.

	Every position is a constant here: the raid map needs no marker part.
]]

export type RaidType = "Marine" | "Endless"

export type Drop = {
	Item: string,
	-- "Weapon": WeaponUnlockService. "Accessory": Appearance.OwnedAccessories.
	Kind: "Weapon" | "Accessory",
	-- 0..1, rolled for every player of the raid; doubled for the top damage dealer.
	Chance: number,
}

export type BossReward = {
	-- Expertise exp for every player in the raid when the boss dies.
	Expertise: number,
	-- Extra for the host of the party.
	HostExpertise: number,
	HostGems: number,
}

export type RaidDefinition = {
	-- Quest name in LegendaryConfig / RaidConfig.DataKey (RaidService:RecordResult).
	Quest: string,
	Waves: number,
	-- Seconds between the wave being announced and its enemies appearing.
	SpawnDelay: number,
	-- Sword Marines of a wave (a Gunner Marine comes with every second one).
	Enemies: (wave: number) -> number,
	-- Template name of the boss of a wave, nil for a wave of marines.
	Boss: (wave: number, random: Random) -> string?,
	-- Defense level of that boss; nil keeps the one of EnemyConfig.
	BossDefense: (bossName: string, wave: number) -> number?,
	BossReward: (bossName: string) -> BossReward,
	-- Finishing the last wave counts as a completed raid.
	CountsCompletion: boolean,
}

local START_ENEMIES = 5
local BOSS_BASE_DEFENSE = 40000

-- Bosses.Normal of the legacy place: the pool of the Endless raid's ordinary boss waves.
local NORMAL_BOSSES = table.freeze({ "ChillyBoss", "MagmaBoss", "QuakeBoss", "CandyBoss", "SandBoss", "FireBoss" })
-- Bosses.Endless.RandomBoss: fights with two fruits picked at random.
local ALL_BOSS = "RandomBoss"

local MARINE_BOSSES: { [number]: string } = table.freeze({
	[5] = "ChillyBoss",
	[10] = "MagmaBoss",
	[15] = "QuakeBoss",
})

local Raids: { [RaidType]: RaidDefinition } = {
	Marine = {
		Quest = "MarineRaid",
		Waves = 15,
		SpawnDelay = 5,
		-- 5 on the first wave, then 2.5 per wave (the legacy loop ran on a fraction).
		Enemies = function(wave: number): number
			return if wave <= 1 then START_ENEMIES else math.floor(START_ENEMIES * wave / 2)
		end,
		Boss = function(wave: number): string?
			return MARINE_BOSSES[wave]
		end,
		BossDefense = function(): number?
			return nil
		end,
		BossReward = function(): BossReward
			return { Expertise = 100, HostExpertise = 0, HostGems = 0 }
		end,
		CountsCompletion = true,
	},
	Endless = {
		Quest = "Endless",
		Waves = 300,
		SpawnDelay = 0,
		Enemies = function(wave: number): number
			return if wave <= 1 then START_ENEMIES else math.floor(math.clamp(START_ENEMIES * wave / 3, 5, 75))
		end,
		-- Every 5th wave a boss; from wave 20 on every 10th is the two-fruit boss.
		Boss = function(wave: number, random: Random): string?
			if wave % 10 == 0 and wave >= 20 then
				return ALL_BOSS
			elseif wave % 5 == 0 then
				return NORMAL_BOSSES[random:NextInteger(1, #NORMAL_BOSSES)]
			end
			return nil
		end,
		BossDefense = function(bossName: string, wave: number): number?
			if bossName == ALL_BOSS then
				return math.floor(BOSS_BASE_DEFENSE * (1 + 0.25 * wave / 10))
			end
			return math.floor(BOSS_BASE_DEFENSE * (1 + 0.05 * wave / 3))
		end,
		BossReward = function(bossName: string): BossReward
			if bossName == ALL_BOSS then
				return { Expertise = 100, HostExpertise = 100, HostGems = 100 }
			end
			return { Expertise = 50, HostExpertise = 50, HostGems = 50 }
		end,
		CountsCompletion = false,
	},
}

return table.freeze({
	Raids = table.freeze(Raids),
	-- Studio has no teleport data: the raid started there is Workspace attribute
	-- "RaidType", or this one.
	StudioType = "Endless" :: RaidType,
	StudioTypeAttribute = "RaidType",

	-- How long the first arrival waits for the rest of the party, and the pause between
	-- the party being complete and the first wave (the legacy loader held its cover for it).
	PartyTimeout = 30,
	StartDelay = 5,
	-- A reserved server retires itself after this long: everyone is sent home.
	ServerLifetime = 40 * 60,
	-- Between "raid over" and the teleport home.
	EndDelay = 6,

	PlayerSpawn = Vector3.new(6, 240, -669),
	-- Studs between the members of the party on the spawn.
	PlayerSpacing = 5,
	BossSpawn = Vector3.new(-8.818, 224.79, -279.419),
	-- Boxes (two opposite corners) the marines appear in; one is picked per marine.
	EnemyAreas = table.freeze({
		table.freeze({ Vector3.new(596.883, 320.898, -342.053), Vector3.new(1003.453, 320.898, 108.01) }),
		table.freeze({ Vector3.new(781.453, 320.898, 238.01), Vector3.new(-750.349, 320.898, 46.977) }),
		table.freeze({ Vector3.new(-1008.349, 320.898, 46.977), Vector3.new(-554.457, 320.898, -300.99) }),
	}),

	Sword = "Sword Marine",
	Gunner = "Gunner Marine",
	-- Level of a marine: a roll in Level plus LevelPerWave per wave, unique among the
	-- living ones (a taken number is rolled again in LevelRetry). Its Defense level is
	-- that number times DefenseFactor.
	Level = NumberRange.new(400, 600),
	LevelRetry = NumberRange.new(300, 650),
	LevelPerWave = 50,
	DefenseFactor = table.freeze({ ["Sword Marine"] = 2, ["Gunner Marine"] = 1 }),
	-- Seconds between two marines of a wave.
	SpawnGap = NumberRange.new(0.1, 0.75),
	-- Pause after a wave is cleared, and how often "is it cleared" is looked at.
	WaveRest = 5,
	ClearCheck = 1,
	-- A wave whose enemies no member has hurt for this long is out of reach (under the
	-- map, in the sea): what is left of it is put next to the party.
	StallTimeout = 90,
	-- A member without a body for this long (and not dead) is out of the raid.
	BodyTimeout = 15,

	TopDamageFactor = 2,
	-- Raid versions of the drops (the bosses of the main map have theirs in BossConfig).
	Drops = table.freeze({
		QuakeBoss = {
			{ Item = "Bisento", Kind = "Weapon", Chance = 1 / 1000 },
			{ Item = "Whitebeard Cape", Kind = "Accessory", Chance = 1 / 100 },
		},
		ChillyBoss = {
			{ Item = "Ice Dagger", Kind = "Weapon", Chance = 2 / 100 },
			{ Item = "Marine Cape Blue", Kind = "Accessory", Chance = 1 / 100 },
			{ Item = "Ice Spear", Kind = "Weapon", Chance = 2 / 100 },
		},
		CandyBoss = {
			{ Item = "Lollipop", Kind = "Weapon", Chance = 1 / 100 },
		},
		MagmaBoss = {
			{ Item = "Magma Gun", Kind = "Weapon", Chance = 5 / 100 },
			{ Item = "Marine Cape Red", Kind = "Accessory", Chance = 1 / 100 },
		},
	} :: { [string]: { Drop } }),
})
