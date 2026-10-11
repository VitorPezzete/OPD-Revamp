--!strict
--[[
	Every equippable weapon: slot, damage and how it is obtained.

	Damage of a basic attack = (Damage + LevelScale * level of the slot's skill), then the
	usual factors (armament haki, BuffWeapons perk) applied by AttackService.

	Source of the numbers: the legacy tool scripts (ServerStorage.Backups.Weapons), which
	are what actually ran. The Workspace.AA.WeaponDamageTypes table the first version of
	this file was generated from was only a display table and disagreed with half of the
	scripts (Aqua Staff 100 vs 30, Shirayuki 350 vs 30, Wakizashi 10 vs 25, ...); seven
	weapons were not in it at all.

	Per-weapon timing, hitboxes, projectiles and special attacks are in AttackConfig.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)

export type WeaponDefinition = {
	Slot: DataTypes.WeaponSlot,
	-- Flat damage added on top of the stat-based damage.
	Damage: number,
	-- Damage per level of the slot's skill. Defaults to 1; 0 for fixed-damage weapons.
	LevelScale: number?,
	-- Base of the BuffWeapons factor (base + 1% per point). Defaults to 1.
	PerkBase: number?,
	Trait: "Melee" | "Sword" | "Special",
	Range: number?,
	-- Level of the slot's skill needed to equip. Weapons without it must be owned.
	LevelRequirement: number?,
	DamageUndefined: boolean?,
}

local Weapons: { [string]: WeaponDefinition } = {
	["Black Leg"] = { Slot = "Melee", Damage = 0, Trait = "Melee", LevelRequirement = 200 },
	Melee = { Slot = "Melee", Damage = 0, Trait = "Melee", LevelRequirement = 0 },
	["Table Kick"] = { Slot = "Melee", Damage = 0, Trait = "Melee", LevelRequirement = 50 },

	Dagger = { Slot = "Sword", Damage = 5, Trait = "Sword" },
	Tachi = { Slot = "Sword", Damage = 20, Trait = "Sword" },
	Wakizashi = { Slot = "Sword", Damage = 25, Trait = "Sword" },
	Katana = { Slot = "Sword", Damage = 30, Trait = "Sword" },
	-- Its legacy tool script was empty (the weapon did nothing): it swings as a plain
	-- sword with the damage of the display table.
	Flail = { Slot = "Sword", Damage = 25, Trait = "Sword" },
	["Kanshou and Bakuya"] = { Slot = "Sword", Damage = 5, Trait = "Sword" },
	Roger = { Slot = "Sword", Damage = 5, Trait = "Sword" },
	["Aqua Staff"] = { Slot = "Sword", Damage = 30, Trait = "Sword" },
	["Golden Fish"] = { Slot = "Sword", Damage = 30, Trait = "Sword" },
	Masamune = { Slot = "Sword", Damage = 30, Trait = "Sword" },
	["Scissors Blade"] = { Slot = "Sword", Damage = 30, Trait = "Sword" },
	Shirayuki = { Slot = "Sword", Damage = 30, Trait = "Sword" },
	Krizma = { Slot = "Sword", Damage = 100, Trait = "Sword" },
	["Ice Dagger"] = { Slot = "Sword", Damage = 100, Trait = "Sword" },
	["Ice Spear"] = { Slot = "Sword", Damage = 100, Trait = "Sword" },
	-- Legacy: 100 without haki, (350 + level) * 2 with it, and a swing that errored
	-- before hitting anything. The non-haki number is used for both.
	["Ultra Great Sword"] = { Slot = "Sword", Damage = 100, Trait = "Sword" },
	-- 115 + level, and the perk factor started at 1.2 instead of 1.
	Lollipop = { Slot = "Sword", Damage = 115, Trait = "Sword", PerkBase = 1.2 },
	-- level + 300 + haki level / 3, times a sun factor for Flare users (Modules.Weapons).
	["Divine Axe"] = { Slot = "Sword", Damage = 300, Trait = "Sword" },
	["Meteorite Sword"] = { Slot = "Sword", Damage = 625, Trait = "Sword" },
	Bisento = { Slot = "Sword", Damage = 1562, Trait = "Sword" },
	-- 375 * level / 500, dealt as Special damage.
	["Lightning Sword"] = { Slot = "Sword", Damage = 0, LevelScale = 0.75, Trait = "Special" },
	-- The fast blades scale with a fifth of the level.
	Kogatana = { Slot = "Sword", Damage = 100, LevelScale = 0.2, Trait = "Sword" },
	["Candy Cane Kogatana"] = { Slot = "Sword", Damage = 100, LevelScale = 0.2, Trait = "Sword" },
	Yoru = { Slot = "Sword", Damage = 150, LevelScale = 0.2, Trait = "Sword" },
	-- Fixed damage, whatever the level.
	["Divine Kogatana"] = { Slot = "Sword", Damage = 1000, LevelScale = 0, Trait = "Sword" },
	Yamato = { Slot = "Sword", Damage = 2222, LevelScale = 0, Trait = "Sword" },
	["Divine Yoru"] = { Slot = "Sword", Damage = 2500000, LevelScale = 0, Trait = "Sword" },

	Slingshot = { Slot = "Sniper", Damage = 5, Trait = "Melee", Range = 30 },
	-- The display table called the shurikens "Sword" damage; the script dealt Melee.
	Stars = { Slot = "Sniper", Damage = 10, Trait = "Melee", Range = 30 },
	Crossbow = { Slot = "Sniper", Damage = 20, Trait = "Sword", Range = 50 },
	Flintlock = { Slot = "Sniper", Damage = 30, Trait = "Melee", Range = 80 },
	-- Shared the Flintlock script.
	Bazooka = { Slot = "Sniper", Damage = 30, Trait = "Melee" },
	-- sniper level * 1.31415926..., Special.
	["Magma Gun"] = { Slot = "Sniper", Damage = 0, LevelScale = 1.31415926535897932, Trait = "Special", Range = 80 },

	["Santa Bag"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
	["Sturdy Rod"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
	["Super Rod"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
	["Tea Cup"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
	-- Unlocked by drinking 100 cups of tea (UtilityService).
	["Tea Kettle"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
	["Wood Rod"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
	["Zombie Head"] = { Slot = "Utility", Damage = 0, Trait = "Melee" },
}

return table.freeze({
	Weapons = table.freeze(Weapons),
	-- Slots that may be left empty ("None"). Melee always has something equipped.
	OptionalSlots = table.freeze({ Sniper = true, Sword = true, Utility = true } :: { [string]: boolean }),
	EmptyName = "None",
})
