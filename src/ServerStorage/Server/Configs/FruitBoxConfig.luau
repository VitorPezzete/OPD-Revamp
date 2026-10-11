--!strict
--[[
	Server-only odds of the treasure hunt: where each compass leads, which box it digs up
	and what a box holds. Every number comes from the legacy tool scripts
	(ServerStorage.Backups.<Compass>.CompassServer, ServerStorage.Boxes.*); clients never
	see them.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local FruitOddsConfig = require(ServerStorage.Server.Configs.FruitOddsConfig)

export type Chance = { Box: string, Chance: number }

export type Compass = {
	-- Fixed burial point; nil: a random Spawner of a random tree of Workspace.Map.Trees.
	FixedTarget: Vector3?,
	-- How the "lucky" roll (only the Tremi trees) is decided.
	Luck: "Expertise" | "Fruit",
	-- TreeM trees are only dug by players in Legendary Mode.
	LegendaryTrees: boolean,
	-- Any Spawner of the chosen tree (true) or always its first one (false).
	RandomSpawner: boolean,
	-- Percent chances. With `Remainder`, that box takes whatever is left of 100.
	Odds: { Chance },
	LegendaryOdds: { Chance }?,
	Remainder: string?,
	-- Every listed chance is multiplied by 1 + Expertise level / 100.
	ExpertiseScaling: boolean,
	-- Chance that the treasure is rolled from AuraOdds instead.
	AuraChance: number,
	AuraOdds: { Chance }?,
	-- The box remembers who dug it up: fruits from it count as found by that player.
	TracksFinder: boolean,
	-- Counts for the Meteorite Sword feat "three treasures within a minute".
	Meteorite: boolean,
}

export type Box = {
	Rarity: FruitConfig.FruitRarity,
	-- Strange boxes always hold an aura fruit; the others roll for it.
	AlwaysAura: boolean,
}

local function odds(list: { Chance }): { Chance }
	for _, entry in list do
		table.freeze(entry)
	end
	return table.freeze(list)
end

-- The friend's strange compasses all lead to the same spot.
local STRANGE_TARGET = Vector3.new(1235.502, 221.95, -3242.559)

local FruitBoxConfig = {}

FruitBoxConfig.Trees = table.freeze({
	-- Folder of Workspace.Map (World.Find).
	Folder = "Trees",
	SpawnerName = "Spawner",
	LuckyTree = "Tremi",
	LegendaryTree = "TreeM",
	-- Used when no tree qualifies.
	FallbackTree = "MiniTremi",
})

FruitBoxConfig.Luck = table.freeze({
	-- "Expertise": a whole number from the Expertise level (capped at RollMax) to RollMax
	-- is drawn; Threshold or more is lucky. 21 in 101 at level 0, certain from level 80.
	RollMax = 100,
	Threshold = 80,
	-- "Fruit": lucky when the player has this fruit.
	Fruit = "Luck",
})

FruitBoxConfig.Compasses = table.freeze({
	["Compass"] = table.freeze({
		Luck = "Expertise",
		LegendaryTrees = true,
		RandomSpawner = true,
		Odds = odds({
			{ Box = "Uncommon Box", Chance = 20 },
			{ Box = "Rare Box", Chance = 1.5 },
			{ Box = "Ultra Rare Box", Chance = 0.1 },
		}),
		LegendaryOdds = odds({
			{ Box = "Uncommon Box", Chance = 20 },
			{ Box = "Rare Box", Chance = 2.5 },
			{ Box = "Ultra Rare Box", Chance = 0.15 },
		}),
		Remainder = "Common Box",
		ExpertiseScaling = true,
		AuraChance = 0,
		TracksFinder = true,
		Meteorite = true,
	}),
	["Silver Compass"] = table.freeze({
		Luck = "Expertise",
		LegendaryTrees = true,
		RandomSpawner = false,
		Odds = odds({
			{ Box = "Uncommon Box", Chance = 95 },
			{ Box = "Rare Box", Chance = 4.5 },
			{ Box = "Ultra Rare Box", Chance = 0.5 },
		}),
		LegendaryOdds = odds({
			{ Box = "Uncommon Box", Chance = 90 },
			{ Box = "Rare Box", Chance = 9 },
			{ Box = "Ultra Rare Box", Chance = 1 },
		}),
		ExpertiseScaling = false,
		AuraChance = 0,
		TracksFinder = true,
		Meteorite = true,
	}),
	["Golden Compass"] = table.freeze({
		Luck = "Fruit",
		LegendaryTrees = false,
		RandomSpawner = false,
		Odds = odds({
			{ Box = "Rare Box", Chance = 80 },
			{ Box = "Ultra Rare Box", Chance = 20 },
		}),
		ExpertiseScaling = false,
		AuraChance = 0,
		TracksFinder = true,
		Meteorite = true,
	}),
	["Strange Compass"] = table.freeze({
		FixedTarget = STRANGE_TARGET,
		Luck = "Expertise",
		LegendaryTrees = false,
		RandomSpawner = false,
		Odds = odds({
			{ Box = "Common Box", Chance = 78.95 },
			{ Box = "Uncommon Box", Chance = 20 },
			{ Box = "Rare Box", Chance = 1 },
			{ Box = "Ultra Rare Box", Chance = 0.05 },
		}),
		ExpertiseScaling = false,
		-- One dig in three finds a strange box.
		AuraChance = 1 / 3,
		AuraOdds = odds({
			{ Box = "Strange Common Box", Chance = 78.95 },
			{ Box = "Strange Uncommon Box", Chance = 20 },
			{ Box = "Strange Rare Box", Chance = 1 },
			{ Box = "Strange Ultra Rare Box", Chance = 0.05 },
		}),
		TracksFinder = false,
		Meteorite = true,
	}),
	["??? Strange Compass"] = table.freeze({
		FixedTarget = STRANGE_TARGET,
		Luck = "Expertise",
		LegendaryTrees = false,
		RandomSpawner = false,
		Odds = odds({}),
		ExpertiseScaling = false,
		AuraChance = 1,
		AuraOdds = odds({
			{ Box = "Strange Rare Box", Chance = 90 },
			{ Box = "Strange Ultra Rare Box", Chance = 10 },
		}),
		TracksFinder = false,
		Meteorite = false,
	}),
} :: { [string]: Compass })

--[[
	Travel plausibility between two digs (legacy anti-cheat numbers): a dig further than
	MinDistance from the previous one needs distance / MaxSpeed seconds to have passed.
]]
FruitBoxConfig.Travel = table.freeze({
	MinDistance = 300,
	MaxSpeed = 650,
})

FruitBoxConfig.Boxes = table.freeze({
	["Common Box"] = table.freeze({ Rarity = "Common", AlwaysAura = false }),
	["Uncommon Box"] = table.freeze({ Rarity = "Uncommon", AlwaysAura = false }),
	["Rare Box"] = table.freeze({ Rarity = "Rare", AlwaysAura = false }),
	["Ultra Rare Box"] = table.freeze({ Rarity = "UltraRare", AlwaysAura = false }),
	["Strange Common Box"] = table.freeze({ Rarity = "Common", AlwaysAura = true }),
	["Strange Uncommon Box"] = table.freeze({ Rarity = "Uncommon", AlwaysAura = true }),
	["Strange Rare Box"] = table.freeze({ Rarity = "Rare", AlwaysAura = true }),
	["Strange Ultra Rare Box"] = table.freeze({ Rarity = "UltraRare", AlwaysAura = true }),
} :: { [string]: Box })

-- An ordinary box holds an aura fruit one time in this many.
FruitBoxConfig.AuraRoll = 500

-- Affinity multiplier -> weight of each of the four affinities of a boxed fruit: the
-- same table as a Beri reroll at the AffinityMerchant.
FruitBoxConfig.AffinityOdds = FruitOddsConfig.RerollOdds.Beri

-- Fruits that join a pool while a SeasonService flag is on.
FruitBoxConfig.Seasonal = table.freeze({
	table.freeze({ Flag = "AliceFruit", Rarity = "UltraRare", Fruit = "Alice" }),
})

-- The owner command: boxes rained around a point. Rolled 1-100, first match wins.
FruitBoxConfig.DropParty = table.freeze({
	Count = 20,
	Odds = odds({
		{ Box = "Ultra Rare Box", Chance = 2 },
		{ Box = "Rare Box", Chance = 8 },
		{ Box = "Uncommon Box", Chance = 40 },
		{ Box = "Common Box", Chance = 50 },
	}),
	Spread = 25,
	MinHeight = 15,
	MaxHeight = 30,
	-- Boxes nobody picked up are removed after this long (the legacy ones stayed forever).
	Lifetime = 600,
})

--[[
	Fruits of each rarity, every one as likely as the others: exactly the contents of the
	legacy ServerStorage.Fruits.<Rarity>Fruits folders (7 / 6 / 19 / 5), which is what
	FruitConfig's rarities were taken from.
]]
local pools: { [string]: { string } } = {}
for fruitName, definition in FruitConfig.Fruits :: { [string]: any } do
	local pool = pools[definition.Rarity]
	if not pool then
		pool = {}
		pools[definition.Rarity] = pool
	end
	table.insert(pool, fruitName)
end
for _, pool in pools do
	table.sort(pool)
	table.freeze(pool)
end
FruitBoxConfig.Pools = table.freeze(pools)

return table.freeze(FruitBoxConfig)
