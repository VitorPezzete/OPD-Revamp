--!strict
--[[
	The hourly PvP world events (legacy WorldEvents script): schedule, per-event rules
	and reward tables. Everything here is server-only; clients are told what to display.
]]

export type Reward = {
	Kind: "Beri" | "Gems" | "Item",
	-- Percent; the chances of one table add up to 100.
	Chance: number,
	-- Fixed amount, or one of Amounts picked at random.
	Amount: number?,
	Amounts: { number }?,
	-- Tool name for Kind = "Item".
	Item: string?,
}

export type EventDefinition = {
	-- Text of the invitation shown to players.
	InviteText: string,
	-- Only players in a crew are invited and may join.
	RequiresCrew: boolean?,
	-- Folder under Assets.Models.Events cloned into Workspace.Instances while the event runs.
	Map: string,
	-- Key of Rewards, and crew experience per rewarded player.
	Rewards: string,
	CrewXP: number,
	[string]: any,
}

local WorldEventConfig = {}

-- Seconds between two events, and how long the invitation stays up.
WorldEventConfig.Interval = 3600
WorldEventConfig.InviteSeconds = 15
-- Accepted players needed for any event to start.
WorldEventConfig.MinPlayers = 2
-- Offset above a spawn part when a player is placed on it.
WorldEventConfig.SpawnHeight = 3
-- Winners are sent back to a random spawn point of the map (WorldConfig.Spawns), at
-- SpawnHeight above it.

WorldEventConfig.Events = table.freeze({
	Deathmatch = table.freeze({
		InviteText = "Participate: Deathmatch",
		Map = "Deathmatch",
		Rewards = "Standard",
		CrewXP = 10,
		-- Seconds between the map appearing and the players being dropped in.
		PrepareSeconds = 2,
		-- After this long everybody loses SuddenDeathDamage health per second.
		SuddenDeathAfter = 300,
		SuddenDeathDamage = 1250,
	}),

	KOTH = table.freeze({
		InviteText = "Participate: KOTH",
		Map = "KOTH",
		Rewards = "Standard",
		CrewXP = 10,
		MatchSeconds = 300,
		MaxPoints = 100,
		-- A point is taken by standing alone (as a team) within CaptureRadius for CaptureSeconds.
		CaptureRadius = 18,
		CaptureSeconds = 10,
		-- Progress lost per second while the point is empty or contested.
		CaptureDecay = 0.5,
		-- Points per second for each capture point a team owns.
		PointsPerSecond = 1,
		Teams = table.freeze({
			Red = Color3.fromRGB(255, 0, 0),
			Blue = Color3.fromRGB(0, 85, 255),
		}),
	}),

	CrewWars = table.freeze({
		InviteText = "Crew Wars - Battle of Crews!",
		RequiresCrew = true,
		Map = "Deathmatch",
		Rewards = "CrewWars",
		CrewXP = 50,
		MinCrews = 2,
		PrepareSeconds = 2,
		SuddenDeathAfter = 300,
		SuddenDeathDamage = 1250,
		-- Fighters further than this from the arena centre are put back on a spawn.
		Boundary = 500,
		-- One highlight colour per crew, reused in order when there are more crews.
		Colors = table.freeze({
			Color3.fromRGB(255, 50, 50),
			Color3.fromRGB(50, 120, 255),
			Color3.fromRGB(50, 200, 50),
			Color3.fromRGB(255, 200, 0),
			Color3.fromRGB(200, 0, 255),
			Color3.fromRGB(255, 130, 0),
			Color3.fromRGB(0, 220, 200),
			Color3.fromRGB(255, 100, 180),
		}),
	}),
} :: { [string]: EventDefinition })

WorldEventConfig.Rewards = table.freeze({
	Standard = table.freeze({
		{ Kind = "Beri", Chance = 74.75, Amount = 750000 },
		{ Kind = "Gems", Chance = 15, Amounts = { 25, 50 } },
		{ Kind = "Item", Chance = 5.25, Item = "Compass", Amount = 9 },
		{ Kind = "Item", Chance = 3.5, Item = "Silver Compass", Amount = 3 },
		{ Kind = "Item", Chance = 1.5, Item = "Golden Compass", Amount = 1 },
	}),
	CrewWars = table.freeze({
		{ Kind = "Beri", Chance = 60, Amount = 2500000 },
		{ Kind = "Gems", Chance = 20, Amounts = { 75, 150 } },
		{ Kind = "Item", Chance = 10, Item = "Compass", Amount = 15 },
		{ Kind = "Item", Chance = 7, Item = "Silver Compass", Amount = 5 },
		{ Kind = "Item", Chance = 3, Item = "Golden Compass", Amount = 2 },
	}),
} :: { [string]: { Reward } })

--[[
	What a weekend (SeasonService flag "Weekend") changes, as multipliers over the normal
	value; read through WorldEventService:GetMultiplier(kind). The legacy weekend never
	touched experience or kill rewards: it shortened the compass token timer (30 -> 25
	minutes) and halved the Golden Compass price at the seller (14 -> 7 DF Coins).
]]
WorldEventConfig.WeekendMultipliers = table.freeze({
	Exp = 1,
	Beri = 1,
	CompassTokenTime = 25 / 30,
	GoldenCompassPrice = 0.5,
} :: { [string]: number })

return table.freeze(WorldEventConfig)
