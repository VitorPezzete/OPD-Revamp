--!strict
--[[
	Bosses: which behaviour drives them, what they drop and the numbers of their attacks.
	Keyed by template name (same key as EnemyConfig). Stats (levels, health, follow
	distance) stay in EnemyConfig.

	Legacy sources: ServerStorage.Bosses.FireBoss.AI_TestFlare, the "Lv2000 Vokun" branch
	of ServerScriptService.Enemies.AIFolder.AI and etc.Unlock.BossDrops.
]]

export type Drop = {
	-- Weapon name (WeaponConfig), granted through WeaponUnlockService.
	Item: string,
	-- 0..1, rolled on the server for the player who landed the kill.
	Chance: number,
}

export type BossDefinition = {
	-- Module name in Server.Modules.Bosses.
	Behaviour: string,
	-- Templates in Assets.Models.Bosses only spawn in the world when this is set;
	-- the others are spawned on demand (EnemyService:SpawnEvent).
	WorldSpawn: boolean?,
	-- Numeric data path incremented for the killer.
	KillCounter: string?,
	Drops: { Drop },
}

local Bosses: { [string]: BossDefinition } = {
	FireBoss = {
		Behaviour = "FireBoss",
		KillCounter = "Bosses.FireBoss.Kills",
		-- math.random(1, 100) <= 5 in the legacy script; only granted when not owned yet.
		Drops = { { Item = "Roger", Chance = 0.05 } },
	},
	["Lv2000 Vokun"] = {
		Behaviour = "Vokun",
		WorldSpawn = true,
		Drops = {},
	},
	-- Raid bosses (RaidRunService spawns them). Drops stay empty here: the raid rolls its
	-- own for every member of the party (RaidRunConfig.Drops), and an entry here would give
	-- the killer a second roll.
	ChillyBoss = { Behaviour = "ChillyBoss", Drops = {} },
	MagmaBoss = { Behaviour = "MagmaBoss", Drops = {} },
	QuakeBoss = { Behaviour = "QuakeBoss", Drops = {} },
	CandyBoss = { Behaviour = "CandyBoss", Drops = {} },
	SandBoss = { Behaviour = "SandBoss", Drops = {} },
	RandomBoss = { Behaviour = "RandomBoss", Drops = {} },
}

-- The fire boss used hardcoded levels for its attacks, not the ones of its Config folder.
local SNIPER_SCALE = 800 / 500
local DEFENSE_SCALE = 700 / 500
local AFFINITY = 1.8

local FireBoss = {
	-- Walk speed of the legacy model's Humanoid. Its Config.WalkSpeed (85, the value in
	-- EnemyConfig) was only applied by status scripts after a stun ended.
	WalkSpeed = 18,
	-- Below this health fraction every attack is dealt as Haki and doubled.
	HakiHealthFraction = 0.65,
	HakiMultiplier = 2,
	-- Fire colors before the haki phase ("r,g,b,r,g,b"): the legacy defaults, green to blue.
	Colors = "0,255,0,0,120,255",

	-- Shave towards the target when it is further than this.
	TeleportMinDistance = 14,
	-- Step length: 50 studs at full health, up to three times that as health drops.
	TeleportStep = 50,
	TeleportStepMaxScale = 3,
	-- Lands this far behind a target that is within one step.
	TeleportBehind = 4,
	-- 2.5 s at full health, shrinking with missing health (down to half).
	TeleportCooldown = 2.5,
	-- Shave away when the target is closer than this while the pillar recharges.
	RetreatBelowDistance = 3,
	RetreatDistance = 30,
	RetreatCooldown = 2,

	-- Lunge when the target is this much higher than the boss.
	DashVerticalGap = 65,
	DashCooldown = 1.2,
	DashDuration = 0.4,
	DashMinSpeed = 120,
	DashMaxSpeed = 250,

	FireFist = {
		Range = 500,
		Cooldown = 4,
		ChargeTime = 2,
		Speed = 500,
		Lifetime = 6,
		Size = 20 * AFFINITY * SNIPER_SCALE,
		Damage = 800 * SNIPER_SCALE * AFFINITY,
		-- Healing of the victim is cut by this fraction for the next regen ticks.
		AntiHealFraction = 0.5,
		AntiHealHits = 15,
	},
	FireWave = {
		Range = 50,
		Cooldown = 2,
		Radius = 50,
		ExpandTime = 0.5,
		Lifetime = 1.5,
		Damage = 1000 * DEFENSE_SCALE * AFFINITY,
	},
	FirePillar = {
		Range = 50,
		Cooldown = 8,
		ChargeTime = 4,
		Speed = 150,
		MaxTravelTime = 2,
		Lifetime = 10,
		-- Full size, reached after GrowTime (8 * scale studs of height per second).
		Size = Vector3.new(10, 40, 10) * DEFENSE_SCALE * AFFINITY,
		GrowTime = 5,
		Damage = 1200 * DEFENSE_SCALE * AFFINITY,
		DamageInterval = 0.25,
	},
}

local Vokun = {
	-- Steps back this far while winding up.
	BackOffDistance = 8,
	WindUpTime = 2.5,
	DashSpeed = 160,
	DashDuration = 0.6,
	-- The dash only connects when the target is within this distance as it starts.
	DashHitRange = 25,
	-- From the start of the dash to the next wind-up.
	RecoverTime = 1.5,
	-- Body contact, as every other enemy.
	ContactReach = 6,
	ContactCooldown = 0.7,
}

return table.freeze({
	Bosses = Bosses,
	FireBoss = FireBoss,
	Vokun = Vokun,
})
