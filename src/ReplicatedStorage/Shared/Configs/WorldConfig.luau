--!strict
--[[
	Map constants, measured in the place.

	The sea is Workspace.Map.Sea.Water0.Model.Water (top 211, bottom 190). The legacy
	Workspace.Spawns parts are gone: their positions live here, so a spawn point is data
	and no longer an instance somebody can move or delete by accident.
]]
local WorldConfig = {}

-- Y of the sea surface: top of the highest water layer.
WorldConfig.SeaLevel = 211
-- Y of the sea bed.
WorldConfig.SeaFloor = 191

-- Rotating spawn points (legacy Workspace.Spawns.Spawn1..Spawn10, part positions).
WorldConfig.Spawns = table.freeze({
	Vector3.new(-8, 213.71, -296),
	Vector3.new(-128, 213.71, -753),
	Vector3.new(45, 221.71, -72),
	Vector3.new(-237, 222.71, -1108),
	Vector3.new(-206, 221.71, -110.5),
	Vector3.new(-76, 212.71, -892),
	Vector3.new(-428, 213.71, -154),
	Vector3.new(-127, 217, -983.2),
	Vector3.new(720, 237, 1191.8),
	Vector3.new(-1281.5, 213.71, -1353),
}) :: { Vector3 }
WorldConfig.SpawnCount = #WorldConfig.Spawns

-- How far above a spawn point a character is placed.
WorldConfig.SpawnHeightOffset = 6.5
-- Spawn points under a roof, where the usual height puts the head in it. Spawn 7 has a
-- ceiling 9.3 studs over the point (its floor is 0.5 under it): the character stands 3.5
-- over the point there, a stud above the floor and well clear of the ceiling.
WorldConfig.SpawnHeights = table.freeze({
	[7] = 3.5,
}) :: { [number]: number }
-- Seconds between a death and the removal of the body (the player is then back on the
-- spawn screen; nothing respawns by itself). Same as the engine's default RespawnTime.
WorldConfig.RespawnDelay = 5

-- Spawn screen camera, relative to the selected spawn point: above and behind it.
WorldConfig.SpawnCameraOffset = Vector3.new(0.01, 40, -50)

-- Any number is accepted (saved data, wrapped into 1..SpawnCount).
function WorldConfig.GetSpawnIndex(index: number?): number
	local number = if type(index) == "number" and index == index then math.floor(index) else 1
	return (number - 1) % WorldConfig.SpawnCount + 1
end

function WorldConfig.GetSpawnPosition(index: number?): Vector3
	return WorldConfig.Spawns[WorldConfig.GetSpawnIndex(index)]
end

-- Where a character stands when it is put on spawn `index` (`height` above the point).
function WorldConfig.GetSpawnCFrame(index: number?, height: number?): CFrame
	local offset = height or WorldConfig.SpawnHeights[WorldConfig.GetSpawnIndex(index)] or WorldConfig.SpawnHeightOffset
	return CFrame.new(WorldConfig.GetSpawnPosition(index) + Vector3.new(0, offset, 0))
end

function WorldConfig.GetRandomSpawnCFrame(random: Random?, height: number?): CFrame
	local index = if random then random:NextInteger(1, WorldConfig.SpawnCount) else math.random(1, WorldConfig.SpawnCount)
	return WorldConfig.GetSpawnCFrame(index, height)
end

return table.freeze(WorldConfig)
