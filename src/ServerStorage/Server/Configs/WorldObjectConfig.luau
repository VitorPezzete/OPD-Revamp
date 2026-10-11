--!strict
--[[
	Numbers of the things lying around the map: treasure chests, barrels / crates, the
	altar and the Meteorite Sword hunt. In the legacy game they were hardcoded in
	ChestSpawner, BarrelsScript, BarrelModule, ChestModule, AltarMain and Meteorite.
]]

export type Honeypot = {
	-- Model / part looked up in Assets.Models (World first).
	Template: string,
	-- Seconds hidden before each appearance (random in the range) and seconds shown.
	MinWait: number,
	MaxWait: number,
	Visible: number,
}

local WorldObjectConfig = {}

WorldObjectConfig.Chests = table.freeze({
	-- Assets.Models.World.<Template>; one chest per part named SpawnerName (or tagged with it).
	Template = "TreasureChest",
	-- Spawner parts are searched in the whole Workspace.Map (they sit inside the islands).
	SpawnerName = "ChestSpawner",
	-- Folder of Workspace.Instances that receives the spawned chests.
	Container = "Chests",
	SpawnHeightOffset = 1,

	OpenRange = 10,
	RespawnSeconds = 300,

	RewardMin = 200,
	RewardMax = 500,
	LuckFruit = "Luck",
	LuckMultiplier = 3,

	-- Two different chests further apart than MinTravelDistance cannot be opened faster
	-- than the trip takes at this speed (studs / second).
	MaxTravelSpeed = 400,
	FastTravelSpeed = 650,
	FastTravelFruits = table.freeze({ "Rumble", "Light" }),
	MinTravelDistance = 100,
})

WorldObjectConfig.Barrels = table.freeze({
	-- Workspace.Map.<Container>: every descendant part with one of these names and a ClickDetector.
	Container = "Barrels",
	Names = table.freeze({ Crate = true, Barrel = true }),

	ClickRange = 8,
	-- A looted barrel is closed for everybody for this long.
	CooldownSeconds = 60,

	-- One random item per barrel; Luck users get LuckExtraMin..LuckExtraMax more.
	Loot = table.freeze({
		"Melon",
		"Pumpkin",
		"Green Apple",
		"Coconut",
		"Cantaloupe",
		"Banana",
		"Apple",
		"Prickly Pear",
		"Large Grapple",
		"Medium Grapple",
		"Small Grapple",
	}),
	LuckFruit = "Luck",
	LuckExtraMin = 1,
	LuckExtraMax = 2,

	MaxTravelSpeed = 650,
	MinTravelDistance = 100,
	-- More than FloodBurst barrels in a row at over FloodRefill per second is not a person.
	FloodBurst = 35,
	FloodRefill = 3.5,

	-- Trap barrels: they give nothing and sit where no player can click by hand, so a
	-- click on one only comes from an auto-farm script. The service flags, it never bans.
	Honeypots = table.freeze({
		table.freeze({ Template = "SpecialBarrel", MinWait = 300, MaxWait = 3600, Visible = 60 }),
		table.freeze({ Template = "SpecialBarrel2", MinWait = 120, MaxWait = 1800, Visible = 180 }),
	} :: { Honeypot }),
	-- Workspace.Map.<Container>.<HoneypotFolder> receives the trap while it is shown.
	HoneypotFolder = "Barrels",
})

WorldObjectConfig.Altar = table.freeze({
	-- Assets.Models.World.<Model>, cloned by AltarService into Workspace.Instances at its
	-- stored pivot. FruitReceptical holds the offered fruit, shown beside Pedestal.
	Model = "Altar",
	Receptacle = "FruitReceptical",
	Pedestal = "Pedestal",
	FruitOffset = CFrame.new(-7, 0, 0.5),

	InteractRange = 8,
	-- No prompt, as in the legacy game: a fruit held this close to the receptacle is laid
	-- on the empty altar, and goes back to whoever laid it once they are LeaveRange away
	-- (the distance at which the legacy altar forgot a player).
	PlaceRange = 5,
	LeaveRange = 13,
	-- Seconds between two looks at who is standing near.
	ScanSeconds = 0.2,
	-- The Legendary offer is shown to whoever places a fruit with at least this total level.
	OfferTotalLevel = 2000,
	OfferSkills = table.freeze({ "Melee", "Defense", "Sniper", "Sword" }),
})

WorldObjectConfig.Meteorite = table.freeze({
	Weapon = "Meteorite Sword",
	-- Requirement 1: compass token capacity.
	CompassTokenLimit = 3,
	-- Requirement 2: this many compass treasures dug up, each within Window seconds of the others.
	CompassFinds = 3,
	CompassWindow = 60,
	-- Requirement 3: buy a Golden Compass from the seller. Requirement 4: sell a rare fruit.
})

return table.freeze(WorldObjectConfig)
