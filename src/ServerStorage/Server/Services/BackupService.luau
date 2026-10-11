--!strict
--[[
	Backups of player data: a snapshot per day played, then one per week, and the ways
	back to them (one player, or everybody through a global keypoint).

	Roblox cannot copy a whole DataStore, so the backup is made profile by profile, when a
	profile loads, and a "global rollback" is a keypoint every profile obeys the next time
	it loads (or at once, with a kick, for the players who are online).

	Server API (nothing here checks a role: callers do. Every argument is validated.)

		BackupService:List(userId) -> (true, entries) | (false, message)                Yields.
			entries = { { Slot: string, Kind: "Daily" | "Weekly", Day: number, Time: number } },
			newest first. Day is the UTC day index (os.time() // 86400), Time the os.time()
			the snapshot was taken at. A slot is "D<day>" or "W<day>" and stays valid until
			that snapshot is dropped (a daily that becomes the weekly one changes letter).
		BackupService:Read(userId, slot) -> data table? (a copy, without `_legacy`)       Yields.
		BackupService:Edit(executor, userId, slot, path, value) -> (ok, message)        Yields.
			Writes one value inside a snapshot. `path` is a dot path as in PlayerData
			("Economy.Beri"). Only an existing number, boolean or string can be written, and
			only with a value of the same type.
		BackupService:RestorePlayer(executor, userId, slot) -> (ok, message)            Yields.
		BackupService:RollbackAll(executor, day) -> (ok, message)                       Yields.
		BackupService:GetRollback() -> { Id: string, Day: number, IssuedAt: number, By: string }?
		BackupService:ClearRollback(executor) -> (ok, message)                          Yields.

		`executor` is the Player giving the order (or a short string naming a console or a
		system): it is only used for the audit log, where all of this is written.

	Store (BackupConfig.StoreName, a DataStore of its own; in Studio and in the Dev place
	an in-memory table, like the profiles there)

		"User_<id>"  { Daily = { snapshot }, Weekly = { snapshot } }, oldest first
		             snapshot = { Day, Time, Prev, Size, Data }
		             Prev: the Day of the snapshot taken before this one (nil for the first)
		             Size: bytes of Data as JSON; Data: the profile without `_legacy`
		"Global"     the rollback keypoint { Id, Day, IssuedAt, By }, absent when there is none

	Taking a snapshot
		A snapshot is the profile as it LOADED: the state at the start of that day, before
		anything was played on it. The copy is made in DataService's load gate (after the
		conversion and Reconcile, before anything reads the data) when `_backupDay` of the
		profile is not today, and written a few seconds later with one UpdateAsync, off the
		join path. `_backupDay` is then set, so the other sessions of that day (rejoins,
		teleports between places) cost no request at all. A write that fails is tried again
		by the loop, with a growing delay, for as long as the player stays. Players online
		across the UTC day change are snapshotted by the same loop, one at a time.
		At most 7 dailies are kept. Weeks turn after Saturday (UTC): when the first snapshot
		of a new week is taken, the newest daily of an earlier week becomes a weekly one
		(it moves, a day is never listed twice); at most 4 weeklies are kept.

	Restoring one player (RestorePlayer)
		In this server: the data is swapped in place for the snapshot and the player is
		kicked, so every system starts again from the saved table.
		Anywhere else: the snapshot is sent to the profile as a ProfileStore message
		(DataService:SendMessage). The server holding the session receives it within
		seconds, applies it and kicks; a profile nobody has loaded applies it when it next
		loads, before the session is announced. A message is consumed by the very save that
		writes the restored data, so it is applied exactly once whatever crashes.
		A restore never loses `_legacy`, `_rollback`, `_backupDay` or a receipt: PurchaseIds
		is the union of both sides, so nothing already granted is granted again. What had
		been bought since the snapshot is rolled back with the rest and is not handed out
		again. Keys the template gained since the snapshot are filled in.

	Rolling everybody back (RollbackAll)
		Writes the keypoint and tells the other servers (MessagingService, and a slow poll
		for the ones that miss it). A profile whose `_rollback` is not the keypoint's Id goes
		back to its state at the START of the keypoint's day, then stores the Id:
		  - the snapshot of that day when there is one;
		  - else the first snapshot after that day when nothing was played in between (its
		    Prev is before the day): that is exactly the state the day started with. A
		    player who has not been back since is simply left as they are;
		  - else the newest snapshot before that day (never anything played after it);
		  - else, with no snapshot that old: a profile created after that day is reset to
		    the template (PurchaseIds kept), any other one takes its oldest snapshot.
		Online players are handled one at a time and kicked when their data changed. A
		snapshot taken after a rollback carries the Id, so it never makes it apply again.
		A restore of one player made after the keypoint was issued wins over it.
		ClearRollback removes the keypoint: profiles not rolled back yet never will be;
		the ones already restored stay restored.

	Not covered: what lives outside the profile (crews, leaderboards, private server
	subscriptions) is not rolled back with it.
]]
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local BackupConfig = require(ServerStorage.Server.Configs.BackupConfig)
local DataTemplate = require(ServerStorage.Server.Configs.DataTemplate)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local DataStoreUtil = require(ServerStorage.Server.Modules.DataStoreUtil)

export type Snapshot = { Day: number, Time: number, Prev: number?, Size: number, Data: { [string]: any } }
export type Record = { Daily: { Snapshot }, Weekly: { Snapshot } }
export type Entry = { Slot: string, Kind: "Daily" | "Weekly", Day: number, Time: number }
export type Keypoint = { Id: string, Day: number, IssuedAt: number, By: string }

type Store = {
	Get: (key: string) -> (boolean, any),
	Update: (key: string, transform: (current: any) -> any) -> (boolean, any),
	Remove: (key: string) -> boolean,
}

-- What the service knows about a player whose profile is loaded (or loading) here.
type Tracked = {
	Profile: any,
	-- False until DataService announced the session: until then a restore needs no kick.
	Live: boolean,
	-- A snapshot that is not in the store yet.
	Copy: Snapshot?,
	Writing: boolean,
	Failures: number,
	RetryAt: number,
}

local SECONDS_PER_DAY = 86400
-- Day 0 (1970-01-01) was a Thursday: with this offset a week index changes on Sunday.
local WEEK_OFFSET = 4
local MESSAGE_KIND = "BackupRestore"
local AUDIT_ACTOR = "BackupService"
-- Survive every restore: the old save, and this service's own bookkeeping.
local PRESERVED = { "_legacy", "_rollback", "_backupDay" }
local RECEIPTS = "PurchaseIds"
local MAX_USER_ID = 2 ^ 53
local MAX_PATH = 128
local MAX_TEXT = 256
local MAX_ACTOR = 64

-- Never the live store in Studio or in the development place, exactly as the profiles.
local MOCK = RunService:IsStudio() or PlaceConfig.Role == "Dev"

local BackupService = Knit.CreateService({
	Name = "BackupService",
	Client = {},
})

local DataService

local store: Store
local tracked: { [Player]: Tracked } = {}
local keypoint: Keypoint? = nil
-- False until the store was asked once: a profile loading before that waits for it.
local keypointKnown = false
local sweeping = false

local function dayNow(): number
	return os.time() // SECONDS_PER_DAY
end

local function weekOf(day: number): number
	return (day + WEEK_OFFSET) // 7
end

local function formatDay(day: number): string
	return os.date("!%Y-%m-%d", day * SECONDS_PER_DAY)
end

local function userKey(userId: number): string
	return BackupConfig.KeyPrefix .. string.format("%.0f", userId)
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

-- Same rule as ProfileStore's Reconcile: only missing string keys are added.
local function reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if type(key) == "string" then
			if target[key] == nil then
				target[key] = deepCopy(value)
			elseif type(target[key]) == "table" and type(value) == "table" then
				reconcile(target[key], value)
			end
		end
	end
end

local function memoryStore(): Store
	local values: { [string]: any } = {}
	return {
		Get = function(key: string): (boolean, any)
			return true, deepCopy(values[key])
		end,
		Update = function(key: string, transform: (current: any) -> any): (boolean, any)
			local result = transform(deepCopy(values[key]))
			if result ~= nil then
				values[key] = deepCopy(result)
			end
			return true, result
		end,
		Remove = function(key: string): boolean
			values[key] = nil
			return true
		end,
	}
end

local function liveStore(): Store
	local dataStore = DataStoreUtil.GetStore(BackupConfig.StoreName)
	return {
		Get = function(key: string): (boolean, any)
			if not dataStore then
				return false, nil
			end
			return DataStoreUtil.Get(dataStore, key)
		end,
		Update = function(key: string, transform: (current: any) -> any): (boolean, any)
			if not dataStore then
				return false, nil
			end
			return DataStoreUtil.Update(dataStore, key, transform)
		end,
		Remove = function(key: string): boolean
			return dataStore ~= nil and DataStoreUtil.Remove(dataStore, key)
		end,
	}
end

-- A Get that gives up after `seconds`: used on the join path only.
local function readBounded(key: string, seconds: number): (boolean, any)
	local done, ok, value = false, false, nil
	task.spawn(function()
		ok, value = store.Get(key)
		done = true
	end)
	local deadline = os.clock() + seconds
	while not done and os.clock() < deadline do
		task.wait(0.1)
	end
	return done and ok, value
end

-- Records ------------------------------------------------------------------------------

local function normalize(value: any): Record
	local record = if type(value) == "table" then value else {}
	if type(record.Daily) ~= "table" then
		record.Daily = {}
	end
	if type(record.Weekly) ~= "table" then
		record.Weekly = {}
	end
	return record
end

local function byDay(a: Snapshot, b: Snapshot): boolean
	return a.Day < b.Day
end

local function hasDay(record: Record, day: number): boolean
	for _, snapshot in record.Daily do
		if snapshot.Day == day then
			return true
		end
	end
	for _, snapshot in record.Weekly do
		if snapshot.Day == day then
			return true
		end
	end
	return false
end

local function newestDay(record: Record): number?
	local newest: number? = nil
	for _, list in { record.Daily, record.Weekly } do
		for _, snapshot in list do
			if not newest or snapshot.Day > newest then
				newest = snapshot.Day
			end
		end
	end
	return newest
end

local function findSlot(record: Record, slot: string): Snapshot?
	local letter, digits = string.match(slot, "^([DW])(%d+)$")
	local day = if digits then tonumber(digits) else nil
	if not letter or not day then
		return nil
	end
	for _, snapshot in if letter == "D" then record.Daily else record.Weekly do
		if snapshot.Day == day then
			return snapshot
		end
	end
	return nil
end

--[[
	Adds a snapshot to a record: promotion of last week's daily, the two limits, then the
	size guard. False when the record already has that day. Runs inside an UpdateAsync
	transform (which may run more than once): it must not yield.
]]
local function insertSnapshot(record: Record, snapshot: Snapshot): boolean
	if hasDay(record, snapshot.Day) then
		return false
	end
	snapshot.Prev = newestDay(record)

	local last = record.Daily[#record.Daily]
	if last and weekOf(last.Day) < weekOf(snapshot.Day) then
		local kept = false
		for _, weekly in record.Weekly do
			if weekOf(weekly.Day) == weekOf(last.Day) then
				kept = true
				break
			end
		end
		if not kept then
			table.remove(record.Daily)
			table.insert(record.Weekly, last)
			table.sort(record.Weekly, byDay)
		end
	end

	table.insert(record.Daily, snapshot)
	table.sort(record.Daily, byDay)
	while #record.Daily > BackupConfig.DailyLimit do
		table.remove(record.Daily, 1)
	end
	while #record.Weekly > BackupConfig.WeeklyLimit do
		table.remove(record.Weekly, 1)
	end

	local total = 0
	for _, list in { record.Daily, record.Weekly } do
		for _, entry in list do
			total += if type(entry.Size) == "number" then entry.Size else 0
		end
	end
	-- Oldest first, weeklies before dailies; the snapshot being added is never dropped.
	while total > BackupConfig.MaxRecordBytes do
		local list = if #record.Weekly > 0 then record.Weekly elseif #record.Daily > 1 then record.Daily else nil
		if not list or list[1] == snapshot then
			break
		end
		total -= if type(list[1].Size) == "number" then list[1].Size else 0
		table.remove(list, 1)
	end
	return true
end

-- The profile as a snapshot of `day`, or nil when it cannot be stored.
local function capture(userId: number, data: { [string]: any }, day: number): Snapshot?
	local copy = {}
	for key, value in data do
		if key ~= "_legacy" then
			copy[key] = deepCopy(value)
		end
	end

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, copy)
	if not ok or #encoded > BackupConfig.MaxSnapshotBytes then
		local reason = if ok then #encoded .. " bytes" else tostring(encoded)
		warn(`[Backup] profile of {userId} cannot be backed up: {reason}`)
		return nil
	end
	return { Day = day, Time = os.time(), Size = #encoded, Data = copy }
end

-- Restoring -------------------------------------------------------------------------------

-- Swaps a profile's content for `source`, in place: the profile and its session keep their table.
local function replaceData(data: { [string]: any }, source: { [string]: any })
	local kept: { [string]: any } = {}
	for _, key in PRESERVED do
		kept[key] = data[key]
	end

	-- Every receipt of both sides, the profile's own (newer) ones last.
	local receipts: { any } = if type(data[RECEIPTS]) == "table" then table.clone(data[RECEIPTS]) else {}
	local older = source[RECEIPTS]
	if type(older) == "table" then
		local missing = {}
		for _, id in older do
			if not table.find(receipts, id) then
				table.insert(missing, id)
			end
		end
		table.move(receipts, 1, #receipts, #missing + 1, missing)
		receipts = missing
	end

	table.clear(data)
	for key, value in source do
		data[key] = deepCopy(value)
	end
	for _, key in PRESERVED do
		data[key] = kept[key]
	end
	data[RECEIPTS] = receipts
	reconcile(data, DataTemplate.Template :: any)
end

--[[
	The snapshot holding the state at the start of `day`, among `list` (oldest first), and
	whether one as old as that day exists. See the header for the order of preference.
]]
local function pick(list: { Snapshot }, day: number): (Snapshot?, boolean)
	local before: Snapshot? = nil
	local after: Snapshot? = nil
	for _, snapshot in list do
		if snapshot.Day == day then
			return snapshot, true
		elseif snapshot.Day < day then
			before = snapshot
		elseif not after then
			after = snapshot
		end
	end
	-- No session started between `day` and that snapshot: it is the state `day` began with.
	if after and after.Prev ~= nil and after.Prev < day then
		return after, before ~= nil
	end
	return before or after, before ~= nil
end

--[[
	Makes a profile obey a keypoint. `unsaved` is the snapshot of this session that is not
	in the record yet; `atLoad` says the profile has just loaded, in which case that
	snapshot IS the current data and choosing it changes nothing. Returns whether the data
	was replaced. Does not yield.
]]
local function applyRollback(userId: number, profile: any, record: Record, target: Keypoint, unsaved: Snapshot?, atLoad: boolean): boolean
	local data = profile.Data
	local list: { Snapshot } = {}
	for _, snapshot in record.Daily do
		table.insert(list, snapshot)
	end
	for _, snapshot in record.Weekly do
		table.insert(list, snapshot)
	end
	local virtual: Snapshot? = nil
	if unsaved and not hasDay(record, unsaved.Day) then
		virtual = unsaved
		unsaved.Prev = newestDay(record)
		table.insert(list, unsaved)
	end
	table.sort(list, byDay)

	local chosen, oldEnough = pick(list, target.Day)
	local createdDay = (tonumber(profile.FirstSessionTime) or 0) // SECONDS_PER_DAY
	local changed = false
	local detail: string
	if not oldEnough and createdDay > target.Day and data._legacy == nil then
		-- Did not exist that day. A converted profile is never "new": its owner played before.
		replaceData(data, DataTemplate.Template :: any)
		changed = true
		detail = "reset to a new profile (created after that day)"
	elseif not chosen then
		detail = "kept (no snapshot)"
	elseif chosen == virtual and atLoad then
		detail = "kept (not played since)"
	else
		replaceData(data, chosen.Data)
		changed = true
		detail = `restored from {formatDay(chosen.Day)}`
	end
	data._rollback = target.Id

	-- Only what changed is worth an audit line: "kept" is every player who was away.
	local line = `user {userId}, keypoint {formatDay(target.Day)}: {detail}`
	if changed then
		AuditLog.Record(AUDIT_ACTOR, "backup:rollback-applied", line)
	else
		print(`[Backup] rollback: {line}`)
	end
	return changed
end

-- A restore sent to this profile from somewhere else (ProfileStore message).
local function applyMessage(player: Player, state: Tracked, message: { [string]: any })
	local data = state.Profile.Data
	local source = message.Data
	local sentAt = if type(message.Time) == "number" then message.Time else 0
	local detail = `user {player.UserId}, slot {tostring(message.Slot)}, ordered by {tostring(message.By)}`
	if type(source) ~= "table" then
		AuditLog.Record(AUDIT_ACTOR, "backup:restore-dropped", `{detail}: no data in the message`)
		return
	end

	local current = keypoint
	if current and data._rollback ~= current.Id and sentAt < current.IssuedAt then
		-- Ordered before a global rollback this profile has not obeyed yet: the rollback decides.
		AuditLog.Record(AUDIT_ACTOR, "backup:restore-dropped", `{detail}: older than the rollback keypoint`)
		return
	end

	replaceData(data, source)
	if current then
		data._rollback = current.Id
	end
	AuditLog.Record(AUDIT_ACTOR, "backup:restore-applied", detail)
	if state.Live then
		DataService:EndSession(player, BackupConfig.RestoreKick)
	end
end

-- Snapshots -------------------------------------------------------------------------------

local function writeSnapshot(player: Player, state: Tracked)
	local snapshot = state.Copy
	if not snapshot then
		state.Writing = false
		return
	end

	local ok = store.Update(userKey(player.UserId), function(current: any): any
		local record = normalize(current)
		-- Nothing to write when another server already stored that day.
		return if insertSnapshot(record, snapshot) then record else nil
	end)
	state.Writing = false

	if not ok then
		state.Failures += 1
		state.RetryAt = os.clock() + math.min(BackupConfig.RetrySeconds * 2 ^ (state.Failures - 1), BackupConfig.RetryMaxSeconds)
		return
	end
	state.Copy = nil
	state.Failures = 0

	-- Bookkeeping no client needs: written straight to the table, not replicated. A
	-- session that ended meanwhile only costs one cancelled UpdateAsync next time.
	local profile = state.Profile
	local stored = profile.Data._backupDay
	if profile:IsActive() and (type(stored) ~= "number" or stored < snapshot.Day) then
		profile.Data._backupDay = snapshot.Day
	end
end

local function scheduleSnapshot(player: Player, state: Tracked, delay: number)
	if state.Writing or not state.Copy then
		return
	end
	state.Writing = true
	task.delay(delay, writeSnapshot, player, state)
end

-- Global rollback -------------------------------------------------------------------------

local function isUsable(player: Player, state: Tracked): boolean
	return tracked[player] == state and state.Live and state.Profile:IsActive()
end

local function rollbackOnline(player: Player, state: Tracked, target: Keypoint)
	local ok, value = store.Get(userKey(player.UserId))
	if not ok then
		-- Left as it is: the loop comes back to it.
		return
	end

	local current = keypoint
	if not current or current.Id ~= target.Id or not isUsable(player, state) or state.Profile.Data._rollback == target.Id then
		return
	end
	if applyRollback(player.UserId, state.Profile, normalize(value), target, state.Copy, false) then
		DataService:EndSession(player, BackupConfig.RollbackKick)
	end
end

-- Applies the keypoint to the online players who have not obeyed it, one at a time.
local function sweepRollback()
	if sweeping then
		return
	end
	sweeping = true

	local target = keypoint
	while target do
		for player, state in table.clone(tracked) do
			local current = keypoint
			if not current or current.Id ~= target.Id then
				break
			end
			if isUsable(player, state) and state.Profile.Data._rollback ~= target.Id then
				rollbackOnline(player, state, target)
				task.wait(BackupConfig.Spread)
			end
		end
		-- Replaced while this pass ran: go again for the new one.
		local current = keypoint
		target = if current and current.Id ~= target.Id then current else nil
	end

	sweeping = false
end

local function parseKeypoint(value: any): Keypoint?
	if type(value) ~= "table" then
		return nil
	end
	if type(value.Id) ~= "string" or value.Id == "" or type(value.Day) ~= "number" or type(value.IssuedAt) ~= "number" then
		return nil
	end
	return { Id = value.Id, Day = value.Day, IssuedAt = value.IssuedAt, By = tostring(value.By) }
end

local function setKeypoint(value: Keypoint?)
	local previous = keypoint
	keypoint = value
	if value and (not previous or previous.Id ~= value.Id) then
		task.spawn(sweepRollback)
	end
end

local function refreshKeypoint()
	local ok, value = store.Get(BackupConfig.GlobalKey)
	if ok then
		setKeypoint(parseKeypoint(value))
	end
	-- Known even after a failure: joins must not wait for a store that is down. The poll
	-- and the sweep catch up once it answers.
	keypointKnown = true
end

local function announceKeypoint()
	if MOCK then
		return
	end
	task.spawn(function()
		-- The payload says nothing: every server reads the keypoint from the store itself.
		local ok, problem = pcall(MessagingService.PublishAsync, MessagingService, BackupConfig.Topic, "changed")
		if not ok then
			warn(`[Backup] the other servers were not told (they poll): {problem}`)
		end
	end)
end

-- Sessions --------------------------------------------------------------------------------

--[[
	DataService's load gate: the profile is converted and reconciled, nothing has read it.
	Copies it for today's snapshot (before any restore, so the state a restore replaced
	can itself be restored), applies the restores waiting in the profile, then the global
	rollback. Only that last step reads the store, and only for a profile the keypoint
	has not been applied to.
]]
local function gate(player: Player, profile: any)
	local data = profile.Data
	local state: Tracked = { Profile = profile, Live = false, Copy = nil, Writing = false, Failures = 0, RetryAt = 0 }
	tracked[player] = state

	local today = dayNow()
	local stored = data._backupDay
	if type(stored) ~= "number" or stored < today then
		state.Copy = capture(player.UserId, data, today)
		if not state.Copy then
			state.RetryAt = os.clock() + BackupConfig.RetryMaxSeconds
		end
	end

	-- Only while this server is starting: a restore must know whether a rollback is pending.
	local deadline = os.clock() + BackupConfig.GateSeconds
	while not keypointKnown and os.clock() < deadline do
		task.wait(0.1)
	end
	if not profile:IsActive() then
		return
	end

	-- Messages already in the profile are handed over here, before this call returns;
	-- later ones arrive after a save, with the session live. A message is marked as
	-- processed and applied in the same step, so the save that drops it holds its data.
	profile:MessageHandler(function(message: any, processed: () -> ())
		if type(message) ~= "table" or message.Kind ~= MESSAGE_KIND or not profile:IsActive() then
			return
		end
		processed()
		applyMessage(player, state, message)
	end)

	local target = keypoint
	if target and data._rollback ~= target.Id and (tonumber(profile.FirstSessionTime) or 0) > target.IssuedAt then
		-- Created after the rollback was ordered: there is nothing to go back to, and no
		-- reason to read the store for every new player while the keypoint stays up.
		data._rollback = target.Id
	end
	if target and data._rollback ~= target.Id then
		local ok, value = readBounded(userKey(player.UserId), BackupConfig.GateSeconds)
		local current = keypoint
		if ok and profile:IsActive() and current and current.Id == target.Id and data._rollback ~= target.Id then
			applyRollback(player.UserId, profile, normalize(value), target, state.Copy, true)
		end
		-- Not read in time: the player loads as they are and the sweep rolls them back.
	end
end

local function onLoaded(player: Player, session: any)
	local state = tracked[player]
	if not state or state.Profile ~= session._profile then
		return
	end
	state.Live = true
	scheduleSnapshot(player, state, BackupConfig.SnapshotDelay)

	local target = keypoint
	if target and state.Profile.Data._rollback ~= target.Id then
		task.spawn(sweepRollback)
	end
end

local function forget(player: Player)
	-- A write under way keeps its own reference and still finishes.
	tracked[player] = nil
end

-- Day changes, failed writes, the keypoint poll and whoever a rollback could not reach.
local function loop()
	local nextPoll = os.clock() + BackupConfig.KeypointPoll
	while true do
		task.wait(BackupConfig.LoopSeconds)

		if os.clock() >= nextPoll then
			nextPoll = os.clock() + BackupConfig.KeypointPoll
			refreshKeypoint()
		end
		if keypoint then
			task.spawn(sweepRollback)
		end

		local today = dayNow()
		for player, state in table.clone(tracked) do
			if not isUsable(player, state) or state.Writing or os.clock() < state.RetryAt then
				continue
			end
			if not state.Copy then
				local data = state.Profile.Data
				local stored = data._backupDay
				if type(stored) == "number" and stored >= today then
					continue
				end
				-- Still here as the day turned: the data as it is now is how the day starts.
				state.Copy = capture(player.UserId, data, today)
				if not state.Copy then
					state.RetryAt = os.clock() + BackupConfig.RetryMaxSeconds
					continue
				end
			end
			scheduleSnapshot(player, state, 0)
			task.wait(BackupConfig.Spread)
		end
	end
end

-- Arguments -------------------------------------------------------------------------------

local function isUserId(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value > 0 and value < MAX_USER_ID
end

local function isSlot(value: any): boolean
	return type(value) == "string" and #value <= 16 and string.match(value, "^[DW]%d+$") ~= nil
end

local function isExecutor(value: any): boolean
	if typeof(value) == "Instance" then
		return value:IsA("Player")
	end
	return type(value) == "string" and #value > 0 and #value <= MAX_ACTOR
end

local function describe(executor: Player | string): string
	return if type(executor) == "string" then executor else `{executor.Name} ({executor.UserId})`
end

local function readRecord(userId: number): (boolean, Record)
	local ok, value = store.Get(userKey(userId))
	return ok, normalize(if ok then value else nil)
end

-- The table holding the last key of a dot path and that key, or nil when the path leads nowhere.
local function resolve(root: { [any]: any }, path: string): ({ [any]: any }?, any)
	local keys = string.split(path, ".")
	local current: any = root
	for index, name in keys do
		if type(current) ~= "table" then
			return nil, nil
		end
		local key: any = name
		if current[key] == nil then
			-- Lists come back from the store with number keys ("SSM.2").
			local number = tonumber(name)
			if number and current[number] ~= nil then
				key = number
			end
		end
		if index == #keys then
			return current, key
		end
		current = current[key]
	end
	return nil, nil
end

-- Server API ------------------------------------------------------------------------------

function BackupService:List(userId: number): (boolean, any)
	if not isUserId(userId) then
		return false, "invalid user id"
	end
	local ok, record = readRecord(userId)
	if not ok then
		return false, "the backup store did not answer"
	end

	local entries: { Entry } = {}
	for _, snapshot in record.Daily do
		table.insert(entries, { Slot = `D{snapshot.Day}`, Kind = "Daily" :: "Daily", Day = snapshot.Day, Time = snapshot.Time })
	end
	for _, snapshot in record.Weekly do
		table.insert(entries, { Slot = `W{snapshot.Day}`, Kind = "Weekly" :: "Weekly", Day = snapshot.Day, Time = snapshot.Time })
	end
	table.sort(entries, function(a: Entry, b: Entry): boolean
		return a.Day > b.Day
	end)
	return true, entries
end

function BackupService:Read(userId: number, slot: string): { [string]: any }?
	if not isUserId(userId) or not isSlot(slot) then
		return nil
	end
	local ok, record = readRecord(userId)
	local snapshot = if ok then findSlot(record, slot) else nil
	-- What the store hands out is already a copy of its own.
	return if snapshot and type(snapshot.Data) == "table" then snapshot.Data else nil
end

function BackupService:Edit(executor: Player | string, userId: number, slot: string, path: string, value: any): (boolean, string)
	if not isExecutor(executor) or not isUserId(userId) or not isSlot(slot) then
		return false, "invalid executor, user id or slot"
	end
	if type(path) ~= "string" or #path == 0 or #path > MAX_PATH or string.find(path, "[^%w_%.]") then
		return false, "invalid path"
	end
	local kind = type(value)
	if kind ~= "number" and kind ~= "boolean" and kind ~= "string" then
		return false, "only a number, a boolean or a string can be written"
	end
	-- NaN and infinity cannot be saved.
	if kind == "number" and (value ~= value or math.abs(value) == math.huge) then
		return false, "the number must be finite"
	end
	if kind == "string" and #value > MAX_TEXT then
		return false, "the text is too long"
	end

	local problem: string? = nil
	local previous: any = nil
	local ok = store.Update(userKey(userId), function(current: any): any
		-- May run again: every run decides on its own.
		problem = nil
		local record = normalize(current)
		local snapshot = findSlot(record, slot)
		if not snapshot or type(snapshot.Data) ~= "table" then
			problem = "no such snapshot (list them again)"
			return nil
		end
		local parent, key = resolve(snapshot.Data, path)
		if not parent or parent[key] == nil then
			problem = `"{path}" does not exist in that snapshot`
			return nil
		end
		if type(parent[key]) ~= kind then
			problem = `"{path}" is a {type(parent[key])}, not a {kind}`
			return nil
		end
		previous = parent[key]
		parent[key] = value
		return record
	end)
	if not ok then
		return false, "the backup store did not answer"
	end
	if problem then
		return false, problem
	end

	AuditLog.Record(executor, "backup:edit", `user {userId}, slot {slot}: {path} {tostring(previous)} -> {tostring(value)}`)
	return true, `{path} = {tostring(value)} (was {tostring(previous)})`
end

function BackupService:RestorePlayer(executor: Player | string, userId: number, slot: string): (boolean, string)
	if not isExecutor(executor) or not isUserId(userId) or not isSlot(slot) then
		return false, "invalid executor, user id or slot"
	end
	local ok, record = readRecord(userId)
	if not ok then
		return false, "the backup store did not answer"
	end
	local snapshot = findSlot(record, slot)
	if not snapshot or type(snapshot.Data) ~= "table" then
		return false, "no such snapshot (list them again)"
	end
	local label = `{slot} ({formatDay(snapshot.Day)})`

	-- Looked up after the read: nothing yields between here and the swap.
	local player = Players:GetPlayerByUserId(userId)
	local state = if player then tracked[player] else nil
	if player and state and isUsable(player, state) then
		replaceData(state.Profile.Data, snapshot.Data)
		local current = keypoint
		if current then
			-- A restore chosen by hand is not undone by a rollback issued before it.
			state.Profile.Data._rollback = current.Id
		end
		AuditLog.Record(executor, "backup:restore", `user {userId} from {label}, in this server`)
		DataService:EndSession(player, BackupConfig.RestoreKick)
		return true, `{player.Name} restored from {label} and kicked to reload`
	end

	local sent = DataService:SendMessage(userId, {
		Kind = MESSAGE_KIND,
		Slot = slot,
		By = describe(executor),
		Time = os.time(),
		Data = snapshot.Data,
	})
	if not sent then
		return false, "the restore could not be sent to the profile"
	end
	AuditLog.Record(executor, "backup:restore", `user {userId} from {label}, sent to the profile`)
	return true, `restore from {label} sent: applied with a kick if they are online elsewhere, otherwise when they next join`
end

function BackupService:RollbackAll(executor: Player | string, day: number): (boolean, string)
	if not isExecutor(executor) then
		return false, "invalid executor"
	end
	local today = dayNow()
	if type(day) ~= "number" or day ~= day or day % 1 ~= 0 or day > today or day < today - BackupConfig.RollbackDays then
		return false, `the day must be one of the last {BackupConfig.RollbackDays}`
	end

	local issued: Keypoint = {
		Id = HttpService:GenerateGUID(false),
		Day = day,
		IssuedAt = os.time(),
		By = describe(executor),
	}
	local ok = store.Update(BackupConfig.GlobalKey, function(): any
		return issued
	end)
	if not ok then
		return false, "the backup store did not answer: nothing was rolled back"
	end

	AuditLog.Record(executor, "backup:rollback-all", `to the start of {formatDay(day)}, keypoint {issued.Id}`)
	setKeypoint(issued)
	announceKeypoint()
	return true, `everybody goes back to the start of {formatDay(day)}: online players are being kicked, the others obey when they join`
end

function BackupService:GetRollback(): Keypoint?
	return if keypoint then table.clone(keypoint) else nil
end

function BackupService:ClearRollback(executor: Player | string): (boolean, string)
	if not isExecutor(executor) then
		return false, "invalid executor"
	end
	if not store.Remove(BackupConfig.GlobalKey) then
		return false, "the backup store did not answer: the keypoint is still there"
	end

	local previous = keypoint
	AuditLog.Record(executor, "backup:rollback-clear", if previous then `keypoint {previous.Id} ({formatDay(previous.Day)})` else "none known here")
	setKeypoint(nil)
	announceKeypoint()
	return true, "keypoint removed: profiles not rolled back yet stay as they are"
end

function BackupService:KnitInit()
	DataService = Knit.GetService("DataService")
	store = if MOCK then memoryStore() else liveStore()
	DataService:SetLoadGate(gate)
end

function BackupService:KnitStart()
	DataService:ObserveData(onLoaded)
	DataService.Releasing:Connect(forget)
	-- A player who left before their session was announced never gets a Releasing.
	Players.PlayerRemoving:Connect(forget)

	task.spawn(refreshKeypoint)
	task.spawn(loop)

	if not MOCK then
		task.spawn(function()
			local ok, problem = pcall(function()
				MessagingService:SubscribeAsync(BackupConfig.Topic, function()
					refreshKeypoint()
				end)
			end)
			if not ok then
				warn(`[Backup] could not subscribe to {BackupConfig.Topic} (the poll still runs): {problem}`)
			end
		end)
	end
end

return BackupService
