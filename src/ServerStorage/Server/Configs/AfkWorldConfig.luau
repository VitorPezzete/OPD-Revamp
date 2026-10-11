--!strict
--[[
	The AFK world, as run in the AFK place (AfkWorldService): what a player earns for
	standing there and how often. What is earned is only stored (data.AFK_World); the AFK
	NPC of the main place pays it out (AfkRewardService).

	Legacy source (place "AFK World"): ServerScriptService.Game.World.
]]

export type Roll = {
	-- data.AFK_World field the reward is added to.
	Field: string,
	-- Percent, out of 100. The entries do not add up to 100: the rest is "nothing".
	Chance: number,
	-- One of these, each as likely as the others.
	Amounts: { number },
}

export type CompassReward = {
	Field: string,
	-- Weight among the entries of the list.
	Weight: number,
	Amount: number,
}

local Rolls: { Roll } = {
	{ Field = "Beri", Chance = 94, Amounts = { 7500 } },
	{ Field = "Gems", Chance = 3.2495, Amounts = { 5, 10 } },
	{ Field = "Compass", Chance = 1.25, Amounts = { 1 } },
	{ Field = "SilverCompass", Chance = 0.5, Amounts = { 1 } },
	{ Field = "GoldenCompass", Chance = 0.0005, Amounts = { 1 } },
}

local CompassRewards: { CompassReward } = {
	{ Field = "Compass", Weight = 70, Amount = 1 },
	{ Field = "SilverCompass", Weight = 30, Amount = 1 },
}

return table.freeze({
	-- Seconds between two rolls of a player, counted from the moment its data is loaded.
	RollInterval = 59,
	Rolls = table.freeze(Rolls),
	-- Every amount (rolls and the compass below) is multiplied by this for Roblox Premium.
	PremiumFactor = 2,

	-- Seconds in the AFK world, carried across sessions (data.AFK_World.CompassTime), that
	-- are worth one of CompassRewards. The counter then starts again.
	CompassSeconds = 5 * 60 * 60,
	CompassRewards = table.freeze(CompassRewards),
	-- The counter lives in memory; this is how often it is written to the saved data (it
	-- is also written when a compass is granted and when the player leaves).
	CompassFlushInterval = 60,

	-- A player still here after RejoinAfter seconds is teleported to the AFK place again,
	-- which is what keeps Roblox from kicking it for being idle. Tried again every
	-- RejoinRetry seconds until it leaves.
	RejoinAfter = 605,
	RejoinRetry = 15,

	-- Seconds a player waits between two requests to return to the main place.
	ReturnCooldown = 5,

	-- Studio only: Workspace attribute (number, 1..3600) every timer above is divided by,
	-- to watch hours go by in minutes. 60 makes a roll every second and a compass every
	-- five minutes.
	StudioSpeedAttribute = "AfkSpeed",
	StudioSpeedMax = 3600,
})
