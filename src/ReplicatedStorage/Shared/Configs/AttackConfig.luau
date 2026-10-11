--!strict
--[[
	Weapon attacks: the defaults of each slot, what each weapon changes, and the special
	attack (legacy "special function" key) of the weapons that have one.

	Every number comes from the legacy tool scripts. Hitboxes: the legacy swords tested a
	box placed in front of the right arm (offset 0, 0.5, -Z); here the same box is placed
	Z studs in front of the root, so it no longer follows the swing animation.

	AttackConfig.Get(weaponName, slot) returns the slot defaults merged with the weapon's
	own values: use it instead of indexing the slot when the weapon is known.
]]
export type AttackDefinition = {
	Cooldown: number,
	-- Skill that scales the damage and receives the exp.
	Skill: "Melee" | "Sword" | "Sniper",
	ExpPerUse: number,
	-- Melee / sword: box in front of the character.
	HitboxSize: Vector3?,
	HitboxDistance: number?,
	-- Only the closest target is hit.
	SingleTarget: boolean?,
	-- The hit lands this long after the click (wind-up). The cooldown includes it.
	HitDelay: number?,
	-- Hits carry the "Slash" tag (swords; a few legacy swords did not send it).
	SlashTag: boolean?,
	-- Observation haki cannot dodge it.
	Undodgeable: boolean?,
	-- Sniper: projectile.
	ProjectileSpeed: number?,
	ProjectileRange: number?,
	-- One-shot effect that draws the shot (default "Bullet", a small grey ball).
	ProjectileEffect: string?,
	-- The legacy bullet was CanCollide false: walls do not stop it, only characters.
	ProjectileIgnoreWorld: boolean?,
}

-- A blade of energy thrown along the aim (most sword specials).
export type SlashDefinition = {
	-- Template name under ReplicatedStorage.Assets (legacy ServerStorage.OtherStuff.SwordSlashes).
	Asset: string,
	Speed: number,
	Lifetime: number,
	-- Damage = Damage + LevelScale * sword level.
	Damage: number,
	LevelScale: number,
	Trait: "Sword" | "Special",
	-- Armament haki: damage multiplier (default 2) and whether it becomes Haki damage (default true).
	HakiMultiplier: number?,
	HakiTrait: boolean?,
	-- Stops at the first character instead of cutting through everyone.
	SingleTarget: boolean?,
	Undodgeable: boolean?,
	-- Starts this many studs ahead of the character.
	Forward: number?,
}

export type SpecialDefinition = {
	Cooldown: number,
	-- Cooldown while armament haki is on.
	HakiCooldown: number?,
	-- Level of the slot's skill.
	LevelRequirement: number,
	-- Usable while fruit powers are sealed (legacy: no DF_Disabled check).
	IgnoreSeal: boolean?,
	-- Generic thrown slash. Without it the weapon's module (Server.Modules.Weapons) runs.
	Slash: SlashDefinition?,
	-- Key of AnimationConfig.Weapons[weapon] played by the user, with its speed and
	-- weight (1 when absent).
	Animation: string?,
	AnimationSpeed: number?,
	AnimationWeight: number?,
	-- A module-driven special whose user swings the weapon as for a basic attack.
	Swing: boolean?,
}

local Slots: { [string]: AttackDefinition } = {
	Melee = { Cooldown = 0.4, Skill = "Melee", ExpPerUse = 4, HitboxSize = Vector3.new(4, 3, 3), HitboxDistance = 2, SingleTarget = true },
	Sword = { Cooldown = 0.4, Skill = "Sword", ExpPerUse = 4, HitboxSize = Vector3.new(4, 3, 5), HitboxDistance = 1, SlashTag = true },
	Sniper = { Cooldown = 2, Skill = "Sniper", ExpPerUse = 4, ProjectileSpeed = 300, ProjectileRange = 1500 },
}

-- Only what differs from the slot. Ranges are legacy speed * bullet lifetime.
local Weapons: { [string]: { [string]: any } } = {
	-- Kicks tested a 4x3x3 box around each leg instead of one in front of the body.
	["Table Kick"] = { Cooldown = 0.5, HitboxSize = Vector3.new(6, 3, 3), HitboxDistance = 0 },
	["Black Leg"] = { Cooldown = 0.5, HitboxSize = Vector3.new(6, 3, 3), HitboxDistance = 0 },

	Wakizashi = { HitboxSize = Vector3.new(4, 4, 4), HitboxDistance = 1.5 },
	Tachi = { HitboxSize = Vector3.new(4, 4, 4), HitboxDistance = 1.5 },
	Katana = { HitboxSize = Vector3.new(5, 3, 7), HitboxDistance = 3 },
	Yoru = { Cooldown = 0.1, HitboxSize = Vector3.new(6, 3, 8), HitboxDistance = 2.5 },
	-- Legacy waited 0.01 s between swings (one per frame); 0.1 like Yoru here.
	["Divine Yoru"] = { Cooldown = 0.1, HitboxSize = Vector3.new(6, 3, 8), HitboxDistance = 2.5, SlashTag = false, Undodgeable = true },
	Kogatana = { Cooldown = 0.13, HitboxSize = Vector3.new(4, 3, 4), HitboxDistance = 0.5 },
	["Candy Cane Kogatana"] = { Cooldown = 0.13, HitboxSize = Vector3.new(4, 3, 4), HitboxDistance = 0.5 },
	["Divine Kogatana"] = { Cooldown = 0.13, HitboxSize = Vector3.new(4, 3, 4), HitboxDistance = 0.5 },
	Krizma = { HitboxSize = Vector3.new(5, 3, 6), HitboxDistance = 1.5 },
	Lollipop = { ExpPerUse = 6, HitboxSize = Vector3.new(5, 3, 6), HitboxDistance = 1.5 },
	["Kanshou and Bakuya"] = { Cooldown = 0.25, SlashTag = false },
	["Ultra Great Sword"] = { HitboxSize = Vector3.new(4, 3, 3), HitboxDistance = 0, SlashTag = false },
	["Aqua Staff"] = { HitboxSize = Vector3.new(4, 4, 4), HitboxDistance = 1.5, SlashTag = false },
	["Divine Axe"] = { HitboxSize = Vector3.new(4, 3, 5), HitboxDistance = 1.5 },
	["Golden Fish"] = { HitboxSize = Vector3.new(4, 3, 5), HitboxDistance = 1.5 },
	["Lightning Sword"] = { Cooldown = 0.2, HitboxSize = Vector3.new(5, 3, 5), HitboxDistance = 1.5, SlashTag = false },
	Masamune = { HitboxSize = Vector3.new(15, 3, 20), HitboxDistance = 10 },
	["Meteorite Sword"] = { Cooldown = 0.6, HitboxSize = Vector3.new(5, 3, 5), HitboxDistance = 1.5 },
	["Scissors Blade"] = { HitboxSize = Vector3.new(5, 4, 5), HitboxDistance = 1.5, SlashTag = false },
	-- 0.7 s wind-up, then the hit, then 0.4 s.
	Bisento = { Cooldown = 1.1, HitDelay = 0.7, HitboxSize = Vector3.new(5, 3, 8.5), HitboxDistance = 4 },
	["Ice Dagger"] = { HitboxSize = Vector3.new(5, 3, 6), HitboxDistance = 1.5 },
	["Ice Spear"] = { HitboxSize = Vector3.new(5, 3, 6), HitboxDistance = 1.5 },
	Shirayuki = { HitboxSize = Vector3.new(5, 3, 7), HitboxDistance = 3 },
	Yamato = { ExpPerUse = 99, HitboxSize = Vector3.new(5, 3, 7), HitboxDistance = 3 },

	Slingshot = { ProjectileSpeed = 150, ProjectileRange = 375 },
	-- The star itself is what flies (the Handle of the tool), spinning.
	Stars = { ProjectileSpeed = 300, ProjectileRange = 1200, ProjectileEffect = "WeaponStarShot" },
	-- 1000 studs/s for 5 s in the legacy script; capped by MaxProjectileRange.
	Crossbow = { ProjectileSpeed = 1000, ProjectileRange = 3000 },
	-- A magma ball (legacy "MagmaBu") at 300 studs/s for 2.5 s, through walls.
	["Magma Gun"] = {
		ExpPerUse = 10,
		ProjectileSpeed = 300,
		ProjectileRange = 750,
		ProjectileEffect = "WeaponMagmaShot",
		ProjectileIgnoreWorld = true,
		Undodgeable = true,
	},
}

local function slash(asset: string, speed: number, lifetime: number, damage: number, levelScale: number, trait: "Sword" | "Special"): SlashDefinition
	return { Asset = asset, Speed = speed, Lifetime = lifetime, Damage = damage, LevelScale = levelScale, Trait = trait }
end

local function with(definition: SlashDefinition, extra: { [string]: any }): SlashDefinition
	for key, value in extra do
		(definition :: any)[key] = value
	end
	return definition
end

local Specials: { [string]: SpecialDefinition } = {
	Dagger = { Cooldown = 3, LevelRequirement = 100, Slash = slash("DaggerSlash", 300, 0.5, 5, 1, "Sword") },
	Wakizashi = { Cooldown = 3, LevelRequirement = 100, Slash = slash("WakizashiSlash", 300, 0.5, 25, 1, "Sword") },
	Tachi = { Cooldown = 3, LevelRequirement = 100, Slash = slash("TachiSlash", 300, 0.5, 20, 1, "Sword") },
	Katana = { Cooldown = 3, LevelRequirement = 100, Slash = slash("KatanaSlash", 300, 0.5, 30, 1, "Sword") },
	-- 2400 * level / 500.
	Yoru = { Cooldown = 24, LevelRequirement = 100, Slash = slash("YoruSlash", 300, 3, 0, 4.8, "Special") },
	-- 250,000,000 * level / 500, at 1500 studs/s for 5 s (capped by MaxProjectileRange).
	["Divine Yoru"] = {
		Cooldown = 0.1,
		LevelRequirement = 100,
		IgnoreSeal = true,
		Slash = with(slash("DivineYoruSlash", 1500, 5, 0, 500000, "Special"), { Undodgeable = true }),
	},
	-- The slow slashes start 3 studs ahead. Legacy lowered the cooldown to 1.5 s the first
	-- time it was used with haki and never raised it back; here it follows the haki.
	Kogatana = {
		Cooldown = 2,
		HakiCooldown = 1.5,
		LevelRequirement = 100,
		Slash = with(slash("KogatanaSlash", 40, 2.5, 100, 0.2, "Sword"), { Forward = 3 }),
	},
	["Candy Cane Kogatana"] = {
		Cooldown = 2,
		HakiCooldown = 1.5,
		LevelRequirement = 100,
		Slash = with(slash("CandyCaneKogatanaSlash", 40, 2.5, 100, 0.2, "Sword"), { Forward = 3 }),
	},
	-- 1000 Special to the first character hit; 4000 with haki, still Special.
	["Divine Kogatana"] = {
		Cooldown = 1.5,
		HakiCooldown = 0.75,
		LevelRequirement = 100,
		Slash = with(slash("DivineKogatanaSlash", 250, 2.5, 1000, 0, "Special"), { HakiMultiplier = 4, HakiTrait = false, SingleTarget = true }),
	},
	Krizma = { Cooldown = 5, LevelRequirement = 100, Slash = slash("KrizmaSlash", 300, 3, 100, 1, "Sword") },
	["Ultra Great Sword"] = { Cooldown = 6, LevelRequirement = 100, Slash = slash("UGSSlash", 300, 3, 100, 1, "Sword") },
	-- Burns when the user owns Flare (Modules.Weapons.Roger).
	Roger = { Cooldown = 5, LevelRequirement = 100, Slash = slash("RogerSlash", 300, 0.5, 300, 1, "Sword") },

	-- Module-driven specials (Server.Modules.Weapons.<Weapon>).
	Lollipop = { Cooldown = 19, LevelRequirement = 100 },
	["Kanshou and Bakuya"] = { Cooldown = 3, LevelRequirement = 100, Animation = "DD1", AnimationSpeed = 16, AnimationWeight = 3 },
	["Aqua Staff"] = { Cooldown = 20, LevelRequirement = 100 },
	["Divine Axe"] = { Cooldown = 20, LevelRequirement = 100 },
	["Lightning Sword"] = { Cooldown = 20, LevelRequirement = 100 },
	["Meteorite Sword"] = { Cooldown = 20, LevelRequirement = 100, IgnoreSeal = true },
	Bisento = { Cooldown = 23, LevelRequirement = 100, Animation = "Skill" },
	["Ice Dagger"] = { Cooldown = 5.5, LevelRequirement = 100, Swing = true },
	["Ice Spear"] = { Cooldown = 8.5, LevelRequirement = 100 },
	Shirayuki = { Cooldown = 8, LevelRequirement = 500, Animation = "Shira", AnimationSpeed = 1.75 },
	Yamato = { Cooldown = 2, LevelRequirement = 250, IgnoreSeal = true },
	["Magma Gun"] = { Cooldown = 8, LevelRequirement = 0, IgnoreSeal = true },
}

local resolved: { [string]: AttackDefinition } = {}

local function get(weaponName: string, slot: string): AttackDefinition?
	local base = Slots[slot]
	if not base then
		return nil
	end
	local overrides = Weapons[weaponName]
	if not overrides then
		return base
	end

	local definition = resolved[weaponName]
	if not definition then
		local merged: { [string]: any } = table.clone(base :: any)
		for key, value in overrides do
			merged[key] = value
		end
		definition = table.freeze(merged) :: any
		resolved[weaponName] = definition
	end
	return definition
end

return table.freeze({
	Melee = table.freeze(Slots.Melee),
	Sword = table.freeze(Slots.Sword),
	Sniper = table.freeze(Slots.Sniper),

	Weapons = table.freeze(Weapons),
	Specials = table.freeze(Specials),
	Get = get,

	-- Armament haki multiplies weapon damage by this and turns it into Haki damage.
	HakiMultiplier = 2,
	-- Fraction of weapon damage added per BuffWeapons perk point.
	WeaponPerkPerPoint = 0.01,
	-- Kicks (Table Kick, Black Leg) are slower than punches.
	KickCooldown = 0.5,
	Kicks = table.freeze({ ["Table Kick"] = true, ["Black Leg"] = true } :: { [string]: boolean }),

	-- Nothing a weapon throws flies further than this (CombatService discards hits from
	-- further than 3000 studs anyway).
	MaxProjectileRange = 3000,
	-- Thrown slashes grow with the sword level: template size * level / SlashFullLevel.
	SlashFullLevel = 500,
	-- Box used when a slash template cannot be found: depth along the flight, height, width.
	SlashFallbackSize = Vector3.new(2, 6, 12),
} :: { [string]: any })
