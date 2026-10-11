--!strict
--[[
	The Burning Compass (legacy ServerStorage.Backups["Burning Compass"].CompassServer and
	etc.Unlock["Burning Compass"]). Handed out by the Legendary Hero; during the day it
	points at a random spot of the western sea, and reaching that spot takes its owner to
	a private island where the fire boss waits.
]]
return table.freeze({
	ToolName = "Burning Compass",
	-- Vector3 attribute on the tool: where it points.
	TargetAttribute = "CompassTarget",

	-- The compass only works while Lighting.ClockTime is strictly between these.
	DayStart = 7,
	DayEnd = 18,
	-- Distance to the target at which the island opens.
	ArrivalRadius = 30,

	-- The target is rolled in this rectangle of the sea (negative X and Z), at sea level.
	TargetMinX = 5046,
	TargetMaxX = 8276,
	TargetMinZ = 2291,
	TargetMaxZ = 4180,
	TargetY = 211,
	-- The beacon of the tool floats this high above the target.
	BeaconHeight = 15,

	-- One island per player at a time, each at one of these spots, far from the map.
	-- (The legacy list of 12 had two repeated entries: two islands could overlap.)
	IslandLocations = table.freeze({
		Vector3.new(-30000, 250, -30000),
		Vector3.new(-30000, 250, -10000),
		Vector3.new(-30000, 250, 0),
		Vector3.new(-30000, 250, 10000),
		Vector3.new(-30000, 250, 30000),
		Vector3.new(-10000, 250, -30000),
		Vector3.new(0, 250, -30000),
		Vector3.new(10000, 250, -30000),
		Vector3.new(30000, 250, -30000),
		Vector3.new(30000, 250, 30000),
	}),
	-- Height of the island pivot; the player is dropped at the location itself.
	IslandY = 216,
	BossName = "FireBoss",
	BossSpawnOffset = CFrame.new(0, 15, 0),
	-- The island is removed this long after its owner dies or leaves it.
	TeardownDelay = 5,
	-- Spawn point (index into WorldConfig.Spawns) the exit leads to, and how high above it.
	ExitSpawn = 10,
	ExitHeight = 10,
})
