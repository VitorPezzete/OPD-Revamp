--!strict
--[[
	Player data backups (Server.Services.BackupService): where the snapshots live, how
	many are kept and how fast the service works.

	The snapshots are in a DataStore of their own, so nothing the backup code writes can
	ever land on a live profile key: profiles are only changed through their own session.
]]
return table.freeze({
	StoreName = "OPD_Backups",
	-- One record per player, the same key as their profile.
	KeyPrefix = "User_",
	-- The global rollback keypoint, in the same store. Cannot collide with a player key.
	GlobalKey = "Global",
	-- MessagingService topic telling the other servers the keypoint changed.
	Topic = "OPD_BackupKeypoint",

	-- Snapshots kept per player: one per day played, then one per week.
	DailyLimit = 7,
	WeeklyLimit = 4,
	-- A DataStore value holds 4 MB. Above this the oldest snapshots of a record are
	-- dropped early, and a single profile bigger than MaxSnapshotBytes is not backed up.
	MaxRecordBytes = 3_000_000,
	MaxSnapshotBytes = 1_000_000,

	-- How far back a global rollback may go (days). The menu offers the same range.
	RollbackDays = 35,
	-- Typed by the developer, and checked again by the server, before a global rollback.
	RollbackPhrase = "ROLLBACK",

	-- Seconds after a session starts before its snapshot is written: off the join path,
	-- and away from the requests ProfileStore makes while the player loads.
	SnapshotDelay = 10,
	-- The one loop of the service: day changes, failed writes, late rollbacks.
	LoopSeconds = 60,
	-- Seconds between two players handled by that loop, so a day change or a rollback is
	-- a trickle of requests instead of one burst per server.
	Spread = 1,
	-- A snapshot that could not be written is tried again after this long, doubled each
	-- time up to the maximum.
	RetrySeconds = 60,
	RetryMaxSeconds = 900,
	-- Servers ask the store for the keypoint this often, in case the message was missed.
	KeypointPoll = 180,
	-- Longest a joining player waits for a backup read (only made when a global rollback
	-- applies to them). Past it they load as they are and are rolled back a moment later.
	GateSeconds = 8,

	RestoreKick = "Your data was restored from a backup by the staff. Please rejoin.",
	RollbackKick = "The game was rolled back to an earlier save. Please rejoin, your data is safe.",
})
