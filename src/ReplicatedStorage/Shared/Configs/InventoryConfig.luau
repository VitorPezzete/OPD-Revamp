--!strict
--[[
	Numbers of the inventory / stats systems that the legacy game kept hardcoded in
	WeaponAchievement, UpdateWeapon, UpgradeTokenCapacity, the Legendary remote and the
	menu LocalScripts.
]]

export type WeaponUnlock = {
	Weapon: string,
	-- Player data counter that unlocks the weapon when it reaches Goal.
	Path: string,
	Goal: number,
}

local InventoryConfig = {}

-- Weapons earned by reaching a counter instead of buying them.
InventoryConfig.WeaponUnlocks = table.freeze({
	{ Weapon = "Kogatana", Path = "Combat.Kills", Goal = 10000 },
	{ Weapon = "Yoru", Path = "Combat.Kills", Goal = 100000 },
	{ Weapon = "Sturdy Rod", Path = "Economy.Fish", Goal = 200 },
	{ Weapon = "Golden Fish", Path = "Economy.Fish", Goal = 1000 },
	{ Weapon = "Zombie Head", Path = "Combat.ZombiesKilled", Goal = 300 },
} :: { WeaponUnlock })

-- The utility list shows this unlock's progress while the Halloween event is on.
InventoryConfig.EventCounter = table.freeze({
	Weapon = "Zombie Head",
	Path = "Combat.ZombiesKilled",
	Goal = 300,
	Label = "Zombies Killed",
})

-- Equipping the first tool also hands the second one once the counter is reached.
InventoryConfig.CompanionTools = table.freeze({
	["Tea Cup"] = table.freeze({ Tool = "Tea Kettle", Path = "Economy.Tea", Goal = 100 }),
} :: { [string]: { Tool: string, Path: string, Goal: number } })

-- Sam's compass token capacity: each extra token of capacity costs more gems.
InventoryConfig.CompassCapacity = table.freeze({
	BaseCost = 50,
	CostPerLimit = 50,
	-- Workspace.Map.Merchants models the upgrade is sold at.
	Merchants = table.freeze({ "QuestMerchant", "QuestMerchant2" }),
})

function InventoryConfig.GetCompassCapacityCost(currentLimit: number): number
	return InventoryConfig.CompassCapacity.BaseCost + currentLimit * InventoryConfig.CompassCapacity.CostPerLimit
end

-- Seconds between two devil fruit slot swaps.
InventoryConfig.FruitSwapCooldown = 30

-- Requirements of the Legendary Mode rebirth at the altar.
InventoryConfig.Legendary = table.freeze({
	Skills = table.freeze({ "Defense", "Melee", "Sniper", "Sword" }),
	SkillLevel = 500,
	Bounty = 10000000,
	AltarRange = 20,
})

return table.freeze(InventoryConfig)
