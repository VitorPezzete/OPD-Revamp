--!strict
--[[
	Developer commands on the data backups: the Backups tab of the menu. All of the work
	is Server.Services.BackupService's; this module only reads the arguments.

	These commands are about a user id, not about the menu's target: a backup is listed
	and restored for somebody who may not be in this server, or anywhere. The id is
	therefore their first argument and the target DevService resolved is ignored.

		BackupList(userId)            the snapshots of a player, newest first
		BackupRestore(userId, slot)   puts one player back on a snapshot
		BackupRollback(day, phrase)   global rollback to the start of a UTC day
		BackupKeypoint()              the global keypoint in force, if any
		BackupClearRollback()         removes it (restores already made stay)

	An answer is a line of text (DevKit). BackupList's is also read by the menu: after the
	id, one "<slot>@<time>" per snapshot, the slot being D or W (daily, weekly) and the
	snapshot's UTC day. Handlers yield on the backup store and trust their caller (DevKit).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local BackupConfig = require(ServerStorage.Server.Configs.BackupConfig)
local DevKit = require(ServerStorage.Server.Modules.DevKit)

local SECONDS_PER_DAY = 86400
local MAX_USER_ID = 2 ^ 53

local handlers: { [string]: DevKit.Handler } = {}

local function today(): number
	return os.time() // SECONDS_PER_DAY
end

local function formatDay(day: number): string
	return os.date("!%Y-%m-%d", day * SECONDS_PER_DAY)
end

-- Whole and positive, never clamped: a clamped id would be somebody else's.
local function readUserId(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value <= 0 or value >= MAX_USER_ID then
		return nil
	end
	return value
end

local function describeKeypoint(keypoint: { [string]: any }?): string
	if not keypoint then
		return "no global rollback in force"
	end
	return `everybody goes back to the start of {formatDay(keypoint.Day)} (ordered by {keypoint.By} on {os.date(
		"!%Y-%m-%d %H:%M",
		keypoint.IssuedAt
	)} UTC, keypoint {keypoint.Id})`
end

function handlers.BackupList(_developer, _target, userIdArg)
	local userId = readUserId(userIdArg)
	if not userId then
		return false, "invalid user id"
	end

	local ok, entries = Knit.GetService("BackupService"):List(userId)
	if not ok then
		return false, tostring(entries)
	end
	if #entries == 0 then
		return true, `{DevKit.Whole(userId)}: no snapshot`
	end

	local parts = {}
	for _, entry in entries do
		table.insert(parts, `{entry.Slot}@{DevKit.Whole(entry.Time)}`)
	end
	return true, `{DevKit.Whole(userId)}: {table.concat(parts, " ")}`
end

function handlers.BackupRestore(developer, _target, userIdArg, slotArg)
	local userId = readUserId(userIdArg)
	local slot = DevKit.Name(slotArg)
	if not userId or not slot then
		return false, "invalid user id or slot"
	end
	return Knit.GetService("BackupService"):RestorePlayer(developer, userId, slot)
end

function handlers.BackupRollback(developer, _target, dayArg, phraseArg)
	-- Not clamped either: a day outside the range is refused, not moved to its edge.
	if type(dayArg) ~= "number" or dayArg ~= dayArg or dayArg % 1 ~= 0 then
		return false, "invalid day"
	end
	-- The menu asks for the phrase; a request that skipped the menu must carry it too.
	if phraseArg ~= BackupConfig.RollbackPhrase then
		return false, `type {BackupConfig.RollbackPhrase} to confirm`
	end
	return Knit.GetService("BackupService"):RollbackAll(developer, dayArg)
end

function handlers.BackupKeypoint(_developer, _target)
	return true, describeKeypoint(Knit.GetService("BackupService"):GetRollback())
end

function handlers.BackupClearRollback(developer, _target)
	return Knit.GetService("BackupService"):ClearRollback(developer)
end

local function getCatalog(): { [string]: any }
	return {
		Backups = {
			RollbackDays = BackupConfig.RollbackDays,
			RollbackPhrase = BackupConfig.RollbackPhrase,
		},
	}
end

-- The same for every target: the keypoint is global. Costs nothing (kept in memory).
local function getState(_target: Player): { [string]: any }
	local keypoint = Knit.GetService("BackupService"):GetRollback()
	return {
		BackupDay = today(),
		BackupKeypoint = if keypoint then describeKeypoint(keypoint) else false,
	}
end

return {
	Handlers = handlers,
	-- Each of these is one or two DataStore requests, and two of them rewrite saves.
	Costs = {
		BackupList = 2,
		BackupRestore = 5,
		BackupRollback = 10,
		BackupClearRollback = 5,
	},
	GetCatalog = getCatalog,
	GetState = getState,
} :: DevKit.CommandModule
