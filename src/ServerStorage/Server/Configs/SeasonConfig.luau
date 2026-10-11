--!strict
--[[
	Calendar-driven content. Each flag is on during a window of the UTC calendar (the
	legacy Time / Weekend / HalloweenFlag / AprilFools / RemoveSanta scripts); Overrides
	forces one on or off regardless of the date, for testing or to retire an event.
]]

export type Calendar = {
	month: number,
	day: number,
	-- 1 = Sunday ... 7 = Saturday
	wday: number,
	yday: number,
}

export type Flag = "Weekend" | "Halloween" | "AprilFools" | "AliceFruit" | "Christmas"

local SeasonConfig = {}

-- Seconds between two looks at the calendar (also the pace of seasonal spawns).
SeasonConfig.CheckInterval = 60

-- Flag -> true / false to ignore the calendar. Empty: everything follows the date.
SeasonConfig.Overrides = table.freeze({} :: { [string]: boolean })

SeasonConfig.Flags = table.freeze({
	-- Friday, Saturday and Sunday.
	Weekend = function(date: Calendar): boolean
		return date.wday == 1 or date.wday == 6 or date.wday == 7
	end,
	-- All of October: pumpkins that release zombies.
	Halloween = function(date: Calendar): boolean
		return date.month == 10
	end,
	-- April 1st only: the Dark and Rumble fruits use their old move sets.
	AprilFools = function(date: Calendar): boolean
		return date.month == 4 and date.day == 1
	end,
	-- April 1st to 14th: the Alice fruit joins the ultra rare spawn pool.
	AliceFruit = function(date: Calendar): boolean
		return date.month == 4 and date.day < 15
	end,
	-- From day 335 of the year (December): Santa stands with the merchants.
	Christmas = function(date: Calendar): boolean
		return date.yday >= 335
	end,
} :: { [string]: (date: Calendar) -> boolean })

-- Mirrors kept for the rest of the game: Workspace attribute "<prefix><Flag>".
SeasonConfig.AttributePrefix = "Season_"

SeasonConfig.Halloween = table.freeze({
	-- One pumpkin at a time, at a random one of these places.
	PumpkinTemplate = "Pumpkin",
	PumpkinSpawns = table.freeze({
		CFrame.new(-5888, 213.687, -1),
		CFrame.new(1592.075, 214.809, 1084.461),
		CFrame.new(118.567, 307.556, 4947.66),
		CFrame.new(990.133, 222.009, -3260.106),
		CFrame.new(1493.964, 298.283, 2153.86),
		CFrame.new(-1075.241, 374.809, 1668),
		CFrame.new(-3132.993, 273.609, -3653.527),
	}),
	ClickRange = 10,

	-- Clicking the pumpkin releases ZombieCount zombies, one every ZombieDelay seconds,
	-- within ZombieSpread studs (on each axis) of where it stood.
	ZombieTemplate = "Zombie",
	ZombieCount = 30,
	ZombieDelay = 0.5,
	ZombieSpread = 120,
	-- A zombie hits for the Melee level of whoever opened the pumpkin times this.
	DamagePerMeleeLevel = 3,

	-- Safety limits the legacy game did not have: zombies never respawn, vanish after
	-- ZombieLifetime seconds, and no new pumpkin appears while its horde would push the
	-- number of walking zombies over MaxAlive.
	ZombieLifetime = 600,
	MaxAlive = 90,
})

export type CandyTask = {
	-- Workspace.Map.Merchants models that accept this delivery.
	Merchants: { string },
	Beri: number?,
	Gems: number?,
	DFCoins: number?,
	Items: { [string]: number }?,
}

SeasonConfig.Christmas = table.freeze({
	-- Model moved into Workspace.Map.Merchants while the flag is on.
	SantaModel = "Santa",
	MerchantsFolder = "Merchants",

	-- Tools handed out by Santa. "Candy" is delivered, "Eatable Candy" is eaten.
	CandyTool = "Candy",
	EatableCandyTool = "Eatable Candy",
	DeliverRange = 8,

	-- Events.XMasLevel 1: deliver a candy to each merchant in order (Events.XMasTask "0".."4").
	Tasks = table.freeze({
		{ Merchants = { "QuestMerchant", "QuestMerchant2" }, Items = { Compass = 2 } },
		{ Merchants = { "QuestFishMerchant" }, Beri = 1000000 },
		{
			Merchants = { "BetterDrinkMerchant" },
			Items = { ["Juice+"] = 4, ["Cider+"] = 4, ["Lemonade+"] = 5, ["Smoothie+"] = 8 },
		},
		{ Merchants = { "AffinityMerchant" }, Gems = 50 },
		-- The last delivery completes level 1.
		{ Merchants = { "SellerMerchant" }, DFCoins = 1 },
	} :: { CandyTask }),

	-- Events.XMasLevel 2: give candies to other players, once per player.
	GiftGems = 10,

	-- Eating a candy: seconds of chewing, then experience in each skill.
	EatSeconds = 2,
	EatExp = table.freeze({
		Sword = { 25000, 40000 },
		Sniper = { 25000, 40000 },
		Melee = { 75000, 120000 },
		Defense = { 20000, 40000 },
	}),
})

return table.freeze(SeasonConfig)
