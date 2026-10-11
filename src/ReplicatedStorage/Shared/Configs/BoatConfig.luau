--!strict
--[[
	Boats: ServerStorage.Backups.Boats.Boat1..Boat5 in the legacy place, sold by the five
	boat merchants under the names below.

	A boat model has a VehicleSeat named "Boat" holding a BodyVelocity and a BodyGyro; top
	speed is the seat's own MaxSpeed. The legacy DriverScript stepped once per frame at
	60 Hz, so its per-frame constants are stored here per second.
]]

export type BoatDefinition = {
	Template: string,
	-- Offset from the merchant's Spawner part.
	Offset: Vector3,
}

export type MerchantDefinition = {
	-- World yaw (degrees) the boat's gyro is pointed at when it spawns.
	Yaw: number,
	-- Boat1Merchant placed boats with the Spawner's position only (offset along world axes).
	WorldAligned: boolean?,
	Offsets: { [string]: Vector3 }?,
}

local Boats: { [string]: BoatDefinition } = {
	Raft = { Template = "Boat1", Offset = Vector3.new(0, 2, 0) },
	Boat = { Template = "Boat2", Offset = Vector3.new(0, 2, 0) },
	Escort = { Template = "Boat3", Offset = Vector3.new(0, 2, 0) },
	Schooner = { Template = "Boat4", Offset = Vector3.new(0, 5, -10) },
	Galleon = { Template = "Boat5", Offset = Vector3.new(0, 2, -20) },
}

local Merchants: { [string]: MerchantDefinition } = {
	Boat1Merchant = { Yaw = 0, WorldAligned = true },
	Boat2Merchant = { Yaw = 180, Offsets = { Galleon = Vector3.new(0, 8, -20) } },
	Boat3Merchant = { Yaw = 180 },
	Boat4Merchant = { Yaw = 90 },
	Boat5Merchant = { Yaw = 180 },
}

return table.freeze({
	Boats = table.freeze(Boats),
	Merchants = table.freeze(Merchants),

	-- Folder of Workspace.Instances holding the spawned boats, and the parts of a boat model.
	FolderName = "Boats",
	SeatName = "Boat",
	SpawnerName = "Spawner",
	OwnerAttribute = "BoatOwner",

	-- Studs per second squared (legacy: 0.5, 0.5 and 0.25 studs/s per frame).
	Acceleration = 30,
	Deceleration = 30,
	ReverseAcceleration = 15,
	-- Degrees per second (legacy: 1 degree per frame).
	TurnRate = 60,
})
