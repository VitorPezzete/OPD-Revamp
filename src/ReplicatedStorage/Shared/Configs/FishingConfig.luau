--!strict
--[[
	Fishing: rods, the reeling minigame, fish, the chef's prices, treasure caches and
	Merlin's deliveries.

	The minigame timeline is defined here once (GetSchedule) and used by both sides: the
	client to animate the targets, the server to decide whether a hit arrived while its
	target was actually up.
]]

export type Difficulty = "Easy" | "Medium" | "Hard" | "Impossible"
-- Scatter: targets pop up all over, hit them before they vanish.
-- Center / Timed: one target at a time (centred / anywhere), only hittable once its ring has closed.
-- Arrows: gamepad lanes, press the side of the arrow once it is past half way.
export type Variant = "Scatter" | "Center" | "Timed" | "Arrows"

export type RodDefinition = {
	-- Seconds before a bite, rolled per cast.
	BiteTime: NumberRange,
	-- Cumulative percent thresholds of a 1-100 roll; anything above Medium is Easy.
	Thresholds: { Impossible: number, Hard: number, Medium: number },
	-- Multipliers on the cache weights.
	CacheWeights: { [string]: number },
	-- Part welded to the right arm while the rod is held (visual only).
	Model: string,
}

export type DifficultyDefinition = {
	Prefix: string,
	MeshScale: number,
	-- A cache drops when a 1..CacheRoll roll lands on CacheThreshold or less.
	CacheRoll: number,
	CacheWeights: { [string]: number },
	-- Seconds taken off the compass token timer for a perfect catch.
	SamSeconds: number,
	-- Minigame pacing: how long a target takes to close, and the delay between targets.
	Lifetime: number,
	Interval: number,
	ButtonSize: UDim2,
}

export type Schedule = {
	-- Seconds after the first target, per target.
	Spawns: { number },
	-- Window in which a hit on that target counts.
	Opens: { number },
	Closes: { number },
	-- When the target is removed.
	Ends: { number },
	Lifetime: number,
	Duration: number,
}

export type CacheDefinition = {
	Fruits: { string },
	FruitCount: NumberRange,
	GoldenAppleChance: number,
	Drinks: { string },
	DrinkChance: number,
	Compass: boolean,
	Beri: NumberRange,
	Gems: number,
}

local FishingConfig = {}

FishingConfig.Rods = table.freeze({
	["Wood Rod"] = {
		BiteTime = NumberRange.new(20, 30),
		Thresholds = { Impossible = 1, Hard = 6, Medium = 30 },
		CacheWeights = {},
		Model = "WoodRod",
	},
	["Sturdy Rod"] = {
		BiteTime = NumberRange.new(15, 20),
		Thresholds = { Impossible = 2, Hard = 12, Medium = 35 },
		CacheWeights = { ["Silver Cache"] = 1.5, ["Gold Cache"] = 1.5, ["Platinum Cache"] = 1.5 },
		Model = "SturdyRod",
	},
	["Super Rod"] = {
		BiteTime = NumberRange.new(5, 15),
		Thresholds = { Impossible = 3, Hard = 18, Medium = 40 },
		CacheWeights = { ["Platinum Cache"] = 2 },
		Model = "SuperRod",
	},
} :: { [string]: RodDefinition })

FishingConfig.RodSlot = "Utility"
-- Horizontal reach of a cast, and how far the angler may wander from the bobber.
FishingConfig.MaxCastDistance = 20
FishingConfig.MaxLineDistance = 60
-- The bobber only floats on the sea: anything solid above this height over sea level is land.
FishingConfig.WaterTolerance = 0.7

-- Each BuffFishing point widens every difficulty threshold / the rare cache weights by this fraction.
FishingConfig.PerkDifficultyBonus = 0.02
FishingConfig.PerkCacheBonus = 0.04

FishingConfig.Difficulties = table.freeze({
	Easy = {
		Prefix = "Small",
		MeshScale = 0.5,
		CacheRoll = 150,
		CacheWeights = {},
		SamSeconds = 15,
		Lifetime = 2.5,
		Interval = 0.45,
		ButtonSize = UDim2.fromScale(0.075, 0.15),
	},
	Medium = {
		Prefix = "Medium",
		MeshScale = 1,
		CacheRoll = 100,
		CacheWeights = { ["Gold Cache"] = 1.25, ["Platinum Cache"] = 1.5 },
		SamSeconds = 30,
		Lifetime = 1.5,
		Interval = 0.45,
		ButtonSize = UDim2.fromScale(0.0625, 0.125),
	},
	Hard = {
		Prefix = "Large",
		MeshScale = 1.5,
		CacheRoll = 60,
		CacheWeights = { ["Gold Cache"] = 1.5, ["Platinum Cache"] = 2 },
		SamSeconds = 60,
		Lifetime = 1,
		Interval = 0.45,
		ButtonSize = UDim2.fromScale(0.05, 0.1),
	},
	Impossible = {
		Prefix = "Huge",
		MeshScale = 2.5,
		CacheRoll = 30,
		CacheWeights = { ["Gold Cache"] = 1.5, ["Platinum Cache"] = 3, ["Aqua Staff"] = 1.5 },
		SamSeconds = 300,
		Lifetime = 1.5,
		Interval = 0.25,
		ButtonSize = UDim2.fromScale(0.05, 0.1),
	},
} :: { [string]: DifficultyDefinition })

FishingConfig.Minigame = table.freeze({
	Targets = 10,
	-- Hits needed to land the fish; the hit count is also its quality out of 10.
	MinimumHits = 7,
	-- Fade-in before the first target.
	Intro = 2,
	-- A target sits still this long before its ring starts closing.
	Settle = 0.35,
	-- Extra time a Scatter target stays up after its ring has closed.
	Linger = 0.3,
	-- Arrows glide in after this delay and only count past this fraction of the glide.
	ArrowSettle = 0.15,
	ArrowEarlyFraction = 0.32,
	-- The one-at-a-time variants run three times faster than the difficulty's pacing.
	SequentialSpeed = 3,
	-- The Timed variant caps the Impossible pacing so it stays humanly possible.
	TimedImpossibleLifetime = 0.75,
	-- Clicking the water this many times costs one hit.
	MissesPerPenalty = 5,
	-- Latency allowance around each hit window, and before the server settles the result.
	EarlyTolerance = 0.1,
	LateTolerance = 0.5,
	SettleGrace = 0.75,
	Variants = table.freeze({ "Scatter", "Center", "Timed" } :: { Variant }),
})

function FishingConfig.GetSchedule(difficulty: string, variant: string): Schedule?
	local definition = FishingConfig.Difficulties[difficulty]
	if not definition then
		return nil
	end

	local minigame = FishingConfig.Minigame
	local lifetime, interval = definition.Lifetime, definition.Interval
	local schedule: Schedule = { Spawns = {}, Opens = {}, Closes = {}, Ends = {}, Lifetime = lifetime, Duration = 0 }

	if variant == "Scatter" then
		for index = 1, minigame.Targets do
			local spawn = (index - 1) * interval
			schedule.Spawns[index] = spawn
			schedule.Opens[index] = spawn
			schedule.Closes[index] = spawn + minigame.Settle + lifetime + minigame.Linger
			schedule.Ends[index] = schedule.Closes[index]
		end
	elseif variant == "Center" or variant == "Timed" then
		if variant == "Timed" and difficulty == "Impossible" then
			lifetime = minigame.TimedImpossibleLifetime
		end
		lifetime /= minigame.SequentialSpeed
		interval /= minigame.SequentialSpeed
		schedule.Lifetime = lifetime

		local period = minigame.Settle + lifetime * 2 + interval
		for index = 1, minigame.Targets do
			local spawn = (index - 1) * period
			schedule.Spawns[index] = spawn
			schedule.Opens[index] = spawn + minigame.Settle + lifetime
			schedule.Closes[index] = spawn + minigame.Settle + lifetime * 2
			schedule.Ends[index] = schedule.Closes[index]
		end
	elseif variant == "Arrows" then
		for index = 1, minigame.Targets do
			local spawn = (index - 1) * interval
			schedule.Spawns[index] = spawn
			schedule.Opens[index] = spawn + minigame.ArrowSettle + lifetime * minigame.ArrowEarlyFraction
			schedule.Closes[index] = spawn + minigame.ArrowSettle + lifetime
			schedule.Ends[index] = schedule.Closes[index]
		end
	else
		return nil
	end

	schedule.Duration = schedule.Ends[minigame.Targets]
	return schedule
end

FishingConfig.FishNames = table.freeze({ "Flooper", "Lubber", "Busser", "Jawber" })

FishingConfig.QualityLabels = table.freeze({ [7] = "Bad", [8] = "Normal", [9] = "Great", [10] = "Perfect" } :: { [number]: string })

-- What the chef pays for a perfect raw fish of each size. Price = base x quality (0.7 - 1) x cooked.
FishingConfig.SizePrices = table.freeze({ Small = 500, Medium = 3000, Large = 7500, Huge = 15000 } :: { [string]: number })
FishingConfig.CookedMultiplier = 5
FishingConfig.ChefMerchant = "FishMerchant"

-- Fire pits / stoves: using a fish within CookRange of one cooks every raw fish carried.
FishingConfig.CookRange = 6
-- The kitchen stoves can also be clicked (a ClickDetector on each), with the same result:
-- the folder that holds them, below Workspace.Map, and the name of a stove part in it.
FishingConfig.StovePath = table.freeze({ "Islands", "Island8", "Kitchen", "Folder" })
FishingConfig.StovePart = "PartC"
FishingConfig.CookSpots = table.freeze({
	Vector3.new(1999.787, 218.71, 569.314),
	Vector3.new(2001.484, 218.71, 571.011),
	Vector3.new(-1809.5, 220.85, 3356.298),
	Vector3.new(90.5, 298.85, -935.702),
	Vector3.new(226.5, 214.85, -0.702),
	Vector3.new(-1753.5, 214.85, -327.702),
})
FishingConfig.CookedColor = BrickColor.new("Bright orange")

FishingConfig.CacheThreshold = 25
-- Relative weights of the cache roll, before rod / difficulty / perk multipliers.
FishingConfig.CacheWeights = table.freeze({
	{ Item = "Copper Cache", Weight = 65 },
	{ Item = "Silver Cache", Weight = 20 },
	{ Item = "Gold Cache", Weight = 10 },
	{ Item = "Platinum Cache", Weight = 2 },
})
-- Rewards the BuffFishing perk makes more likely.
FishingConfig.PerkBoostedRewards = table.freeze({ ["Platinum Cache"] = true, ["Aqua Staff"] = true } :: { [string]: boolean })

-- The Aqua Staff joins the cache roll for Super Rod anglers who sold enough fish to the chef.
FishingConfig.AquaStaff = table.freeze({
	Item = "Aqua Staff",
	Rod = "Super Rod",
	Weight = 1,
	ChefGiftRequirement = 500000,
})

local COMMON_FRUITS = { "Cantaloupe", "Banana", "Apple", "Prickly Pear" }
local ALL_FRUITS = { "Melon", "Pumpkin", "Green Apple", "Coconut", "Cantaloupe", "Banana", "Apple", "Prickly Pear" }
local BASIC_DRINKS = { "Smoothie", "Cider", "Juice", "Lemonade" }
local ALL_DRINKS = { "Smoothie", "Cider", "Juice", "Lemonade", "Smoothie+", "Cider+", "Juice+", "Lemonade+" }

FishingConfig.GoldenApple = "Golden Apple"
FishingConfig.CompassItem = "Compass"

FishingConfig.Caches = table.freeze({
	["Copper Cache"] = {
		Fruits = COMMON_FRUITS,
		FruitCount = NumberRange.new(6, 8),
		GoldenAppleChance = 0,
		Drinks = BASIC_DRINKS,
		DrinkChance = 0.1,
		Compass = false,
		Beri = NumberRange.new(10000, 10000),
		Gems = 0,
	},
	["Silver Cache"] = {
		Fruits = COMMON_FRUITS,
		FruitCount = NumberRange.new(6, 8),
		GoldenAppleChance = 0,
		Drinks = BASIC_DRINKS,
		DrinkChance = 0.3,
		Compass = false,
		Beri = NumberRange.new(25000, 25000),
		Gems = 0,
	},
	["Gold Cache"] = {
		Fruits = ALL_FRUITS,
		FruitCount = NumberRange.new(6, 8),
		GoldenAppleChance = 0.25,
		Drinks = ALL_DRINKS,
		DrinkChance = 0.5,
		Compass = false,
		Beri = NumberRange.new(50000, 50000),
		Gems = 0,
	},
	["Platinum Cache"] = {
		Fruits = ALL_FRUITS,
		FruitCount = NumberRange.new(6, 8),
		GoldenAppleChance = 0.4,
		Drinks = ALL_DRINKS,
		DrinkChance = 0.7,
		Compass = true,
		Beri = NumberRange.new(100000, 350000),
		Gems = 15,
	},
} :: { [string]: CacheDefinition })

-- Merlin, the fisherman: deliveries, trust and the Super Rod.
FishingConfig.Merlin = table.freeze({
	Merchant = "QuestFishMerchant",
	-- Seconds between two batches of packages.
	Cooldown = 60,
	-- Deliveries needed before he hands out three packages at a time (and the odd special one).
	TrustGoal = 50,
	TrustedExtraPackages = 2,
	SpecialChance = 0.09,
	-- Chance that a package is addressed to the Haki master while he is around.
	TimedChance = 0.05,
	-- How close to the addressee the package must be carried.
	DeliveryRange = 5,
	-- Fastest plausible travel (studs per second) between two deliveries; faster is a teleport.
	MaxTravelSpeed = 300,
	FirstDeliveryItem = "Wood Rod",
	SuperRod = table.freeze({
		Item = "Super Rod",
		Price = 1000000,
		FishRequirement = 200,
		RequiredItem = "Sturdy Rod",
	}),
	Packages = table.freeze({
		Package = { Beri = NumberRange.new(10000, 20000), Gems = 0, SamSeconds = 30 },
		["Special Package"] = {
			Beri = NumberRange.new(75000, 150000),
			Gems = 10,
			SamSeconds = 300,
			Color = Color3.fromRGB(255, 255, 255),
		},
		["Timed Package"] = {
			Beri = NumberRange.new(50000, 175000),
			Gems = 10,
			SamSeconds = 300,
			Color = Color3.fromRGB(25, 12, 25),
		},
		["Timed Special Package"] = {
			Beri = NumberRange.new(750000, 1500000),
			-- 250 gems the first time (with the sword), 100 afterwards.
			Gems = 100,
			FirstGems = 250,
			SamSeconds = 1800,
			Item = "Lightning Sword",
			Color = Color3.fromRGB(97, 17, 100),
		},
	} :: { [string]: { Beri: NumberRange, Gems: number, SamSeconds: number, FirstGems: number?, Item: string?, Color: Color3? } }),
})

return table.freeze(FishingConfig)
