--!strict
--[[
	Everything the moderator menu can ask for (the menu itself: Server.StaffClient.Mod,
	handed only to moderators by StaffDelivery). AdminService is the only caller: it has
	already checked the role and its rate limit, and the role is checked again here.

		StaffActions.Run(executor, action, payload) -> ok, message, result?

	Players   Spectate, Goto, Bring, Kick, Ban, Unban, GlobalKick: the commands of
	          Server.Modules.Commands, run through CommandRunner (arguments rebuilt from
	          their declared types, role compared with the command's group, audit log).
	Data      DataRead   the saved data of a player of THIS server, as it is in memory.
	                     Somebody who is not here is answered "offline": a profile is
	                     never loaded for the menu, that would take the session away from
	                     the server the player is (or will be) in. Their backups remain.
	          DataWrite  one existing number, boolean or text at a dot path, replaced by a
	                     value of the same type.
	Backups   BackupList, BackupRead, BackupEdit, BackupRestore: BackupService, which does
	          no role checks of its own. A place without that service answers
	          "unavailable". A restore takes two requests: the first is answered with a
	          short-lived token, the second must bring it back.
	Server    Shutdown   { Seconds, Reason? }: closes this server after a countdown of
	                     10 seconds to an hour (ServerPolicyService). The reason is shown
	                     to everybody, filtered.

	Rules shared by every action
	- A payload is a table of plain values straight from a remote: each field is read
	  through one of the readers below, or the request is refused.
	- Whatever changes a player (kick, ban, bring, write, edit, restore) needs
	  Permissions.CanTarget: the executor must outrank the target. An owner may also
	  change their own data. Reading and watching are open to every moderator.
	- `_legacy`, `_version`, `_rollback` and `PurchaseIds` are never written, and the
	  converted legacy save (large, and of no use to a moderator) is never sent.
	- Profiles and snapshots are large: one per request, on a budget of its own.
	- Every action that reads or changes somebody's data is written to the AuditLog.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local AuditLog = require(ServerStorage.Server.Modules.AuditLog)
local CommandRunner = require(ServerStorage.Server.Modules.CommandRunner)
local Permissions = require(ServerStorage.Server.Modules.Permissions)

type Payload = { [any]: any }
type Handler = (executor: Player, payload: Payload) -> (boolean, string, any?)
-- One step of a dot path: the table it was found in and its real key (a list is indexed
-- by number, although the path spells the index as text).
type Step = { Parent: { [any]: any }, Key: any, Text: string }

local StaffActions = {}

-- The answer to anything that is not an action. AdminService gives the very same answer
-- to a player without the role, whatever was asked.
StaffActions.Unknown = "Unknown request."

local REQUIRED_ROLE: Permissions.Role = "Mod"
local SELF_EDIT_ROLE: Permissions.Role = "Owner"

local MAX_ACTION_LENGTH = 32
local MAX_USER_ID = 2 ^ 53
local MAX_PATH_LENGTH = 200
local MAX_PATH_DEPTH = 12
local MAX_TEXT_LENGTH = 200
local MAX_SLOT_LENGTH = 64
-- A written number stays within +/- this; one that is not negative today stays that way.
local MAX_NUMBER = 1e12
local MAX_BACKUP_ENTRIES = 100
-- Seconds a restore waits for its confirmation.
local RESTORE_CONFIRM_SECONDS = 30
-- Countdown of a shutdown: long enough to be read, never longer than an hour.
local MIN_SHUTDOWN_SECONDS = 10
local MAX_SHUTDOWN_SECONDS = 3600

-- Top-level keys of a profile that only the data layer may write.
local PROTECTED_KEYS = table.freeze({ "_legacy", "_version", "_rollback", "PurchaseIds" })
-- Top-level keys that are not sent to the menu.
local HIDDEN_KEYS = table.freeze({ "_legacy" })

-- Menu action -> command of Server.Modules.Commands.
local COMMANDS: { [string]: string } = table.freeze({
	Spectate = "spectate",
	Goto = "goto",
	Bring = "bring",
	Kick = "kick",
	Ban = "ban",
	Unban = "unban",
	GlobalKick = "globalkick",
})

-- Profiles, snapshots and DataStore calls: { burst 4, one more every 4 seconds }.
local heavyLimiter = RateLimiter.new(4, 0.25)
local BUSY = "Too many data requests, wait a few seconds."

local pendingRestores: { [Player]: { Token: string, UserId: number, Slot: string, Expires: number } } = {}

local function readUserId(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value < 1 or value > MAX_USER_ID or value % 1 ~= 0 then
		return nil
	end
	return value
end

local function readSlot(value: unknown): string?
	if type(value) ~= "string" or #value == 0 or #value > MAX_SLOT_LENGTH or string.find(value, "%c") then
		return nil
	end
	return value
end

-- The keys of a dot path, or nil: no empty key, no control character, nothing protected.
local function readPath(value: unknown): { string }?
	if type(value) ~= "string" or #value == 0 or #value > MAX_PATH_LENGTH or string.find(value, "%c") then
		return nil
	end
	local keys = string.split(value, ".")
	if #keys > MAX_PATH_DEPTH then
		return nil
	end
	for _, key in keys do
		if key == "" or table.find(PROTECTED_KEYS, key) then
			return nil
		end
	end
	return keys
end

--[[
	Follows the keys through `root`. Every step must exist; a key that is not there as
	text is tried as a list index. nil when the path leads nowhere.
]]
local function walk(root: { [any]: any }, keys: { string }): { Step }?
	local steps: { Step } = table.create(#keys)
	local current: any = root
	for _, text in keys do
		if type(current) ~= "table" then
			return nil
		end
		local key: any = text
		if current[key] == nil then
			key = tonumber(text)
			if key == nil or current[key] == nil then
				return nil
			end
		end
		table.insert(steps, { Parent = current, Key = key, Text = text })
		current = current[key]
	end
	return steps
end

-- The value that may replace `current`, or nil and why not.
local function coerce(current: any, value: unknown): (any, string?)
	local kind = type(current)
	if kind == "number" then
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			return nil, "That value must be a number."
		end
		return math.clamp(value, if current >= 0 then 0 else -MAX_NUMBER, MAX_NUMBER), nil
	elseif kind == "boolean" then
		if type(value) ~= "boolean" then
			return nil, "That value must be true or false."
		end
		return value, nil
	elseif kind == "string" then
		if type(value) ~= "string" then
			return nil, "That value must be text."
		end
		return string.sub((string.gsub(value, "%c", " ")), 1, MAX_TEXT_LENGTH), nil
	end
	return nil, "Only a single number, true/false or text can be written."
end

-- What the menu is shown of a profile or a snapshot. The remote copies it on the way out.
local function view(data: { [any]: any }): { [any]: any }
	local shown = table.clone(data)
	for _, key in HIDDEN_KEYS do
		shown[key] = nil
	end
	return shown
end

local function canChange(executor: Player, userId: number): boolean
	if userId == executor.UserId then
		return Permissions.Has(executor, SELF_EDIT_ROLE)
	end
	return Permissions.CanTarget(executor, userId)
end

local function describeUser(userId: number): string
	local player = Players:GetPlayerByUserId(userId)
	return if player then `{player.Name} ({userId})` else tostring(userId)
end

local function getBackups(): any?
	local ok, service = pcall(Knit.GetService, "BackupService")
	return if ok then service else nil
end

-- Calls a BackupService method (they yield, and may throw on a DataStore failure).
local function callBackups(method: string, ...: any): (boolean, any, any)
	local service = getBackups()
	if not service or type(service[method]) ~= "function" then
		return false, nil, nil
	end
	local ok, first, second = pcall(service[method], service, ...)
	if not ok then
		warn(`[StaffActions] BackupService:{method} failed: {tostring(first)}`)
		return false, nil, nil
	end
	return true, first, second
end

local UNAVAILABLE = "Backups are unavailable in this server."

local Handlers: { [string]: Handler } = {}

for action, command in COMMANDS do
	Handlers[action] = function(executor: Player, payload: Payload): (boolean, string, any?)
		local ok, lines = CommandRunner.Run(executor, command, payload)
		return ok, table.concat(lines, "\n"), nil
	end
end

function Handlers.DataRead(executor: Player, payload: Payload): (boolean, string, any?)
	local userId = readUserId(payload.UserId)
	if not userId then
		return false, "Pick a player or type a user id.", nil
	elseif not heavyLimiter:Consume(executor) then
		return false, BUSY, nil
	end

	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return true, "That user is not in this server: only their backups can be read.", { Online = false, UserId = userId }
	end
	local data = Knit.GetService("DataService"):GetData(target)
	if not data then
		return false, `{target.Name}'s data is not loaded yet.`, nil
	end

	AuditLog.Record(executor, "data:read", describeUser(userId))
	return true, `Data of {target.Name}, as it is now.`, {
		Online = true,
		UserId = userId,
		Name = target.Name,
		Data = view(data.Data :: any),
	}
end

function Handlers.DataWrite(executor: Player, payload: Payload): (boolean, string, any?)
	local userId = readUserId(payload.UserId)
	local keys = readPath(payload.Path)
	if not userId then
		return false, "Pick a player or type a user id.", nil
	elseif not keys then
		return false, "That path cannot be written.", nil
	elseif not canChange(executor, userId) then
		AuditLog.Record(executor, "denied", `data:write {describeUser(userId)}`)
		return false, "You cannot edit that player.", nil
	end

	local target = Players:GetPlayerByUserId(userId)
	local data = target and Knit.GetService("DataService"):GetData(target)
	if not target or not data or not data:IsActive() then
		return false, "That player's data is not loaded in this server.", nil
	end

	local steps = walk(data.Data :: any, keys)
	if not steps then
		return false, "There is no saved value at that path.", nil
	end
	local last = steps[#steps]
	local current = last.Parent[last.Key]
	local nextValue, problem = coerce(current, payload.Value)
	if problem then
		return false, problem, nil
	end

	--[[
		PlayerData.Set is the only write path (it announces the change to the game and
		to the owner's client) and it indexes by text. A value inside a list is therefore
		changed in place and the innermost table reached by text keys alone is set again,
		which is how the rest of the game writes lists.
	]]
	local textKeys: { string } = {}
	for _, step in steps do
		if type(step.Key) ~= "string" then
			break
		end
		table.insert(textKeys, step.Text)
	end
	if #textKeys == #steps then
		data:Set(table.concat(textKeys, "."), nextValue)
	elseif #textKeys == 0 then
		return false, "That path cannot be written.", nil
	else
		last.Parent[last.Key] = nextValue
		local owner = steps[#textKeys + 1].Parent
		data:Set(table.concat(textKeys, "."), owner)
	end

	local path = table.concat(keys, ".")
	AuditLog.Record(executor, "data:write", `{describeUser(userId)} {path}: {tostring(current)} -> {tostring(nextValue)}`)
	return true, `{path}: {tostring(current)} -> {tostring(nextValue)}`, nil
end

function Handlers.BackupList(executor: Player, payload: Payload): (boolean, string, any?)
	local userId = readUserId(payload.UserId)
	if not userId then
		return false, "Pick a player or type a user id.", nil
	elseif not getBackups() then
		return false, UNAVAILABLE, nil
	elseif not heavyLimiter:Consume(executor) then
		return false, BUSY, nil
	end

	local called, ok, entries = callBackups("List", userId)
	if not called then
		return false, "The backups could not be listed, try again.", nil
	elseif not ok or type(entries) ~= "table" then
		return false, if type(entries) == "string" then entries else "The backups could not be listed.", nil
	end

	-- Rebuilt field by field: only what the menu shows leaves the server.
	local list = {}
	for index, entry in entries do
		if index > MAX_BACKUP_ENTRIES or type(entry) ~= "table" then
			break
		end
		table.insert(list, {
			Slot = tostring(entry.Slot),
			Kind = tostring(entry.Kind),
			Day = tonumber(entry.Day) or 0,
			Time = tonumber(entry.Time) or 0,
		})
	end
	AuditLog.Record(executor, "backup:list", describeUser(userId))
	return true, `{#list} backup(s) of {describeUser(userId)}, newest first.`, { UserId = userId, Entries = list }
end

function Handlers.BackupRead(executor: Player, payload: Payload): (boolean, string, any?)
	local userId = readUserId(payload.UserId)
	local slot = readSlot(payload.Slot)
	if not userId or not slot then
		return false, "Pick a user and one of their backups.", nil
	elseif not getBackups() then
		return false, UNAVAILABLE, nil
	elseif not heavyLimiter:Consume(executor) then
		return false, BUSY, nil
	end

	local called, snapshot = callBackups("Read", userId, slot)
	if not called or type(snapshot) ~= "table" then
		return false, "That backup could not be read.", nil
	end
	AuditLog.Record(executor, "backup:read", `{describeUser(userId)} slot {slot}`)
	return true, `Backup {slot} of {describeUser(userId)}.`, { UserId = userId, Slot = slot, Data = view(snapshot) }
end

function Handlers.BackupEdit(executor: Player, payload: Payload): (boolean, string, any?)
	local userId = readUserId(payload.UserId)
	local slot = readSlot(payload.Slot)
	local keys = readPath(payload.Path)
	if not userId or not slot then
		return false, "Pick a user and one of their backups.", nil
	elseif not keys then
		return false, "That path cannot be written.", nil
	elseif not canChange(executor, userId) then
		AuditLog.Record(executor, "denied", `backup:edit {describeUser(userId)}`)
		return false, "You cannot edit that player.", nil
	elseif not getBackups() then
		return false, UNAVAILABLE, nil
	-- Two DataStore calls: the snapshot is read to check the value's type, then written.
	elseif not heavyLimiter:Consume(executor, 2) then
		return false, BUSY, nil
	end

	local called, snapshot = callBackups("Read", userId, slot)
	if not called or type(snapshot) ~= "table" then
		return false, "That backup could not be read.", nil
	end
	local steps = walk(snapshot, keys)
	if not steps then
		return false, "There is no saved value at that path.", nil
	end
	for _, step in steps do
		-- BackupService takes a dot path of text keys: an index into a list cannot be named.
		if type(step.Key) ~= "string" then
			return false, "A value inside a list cannot be edited in a backup.", nil
		end
	end
	local last = steps[#steps]
	local current = last.Parent[last.Key]
	local nextValue, problem = coerce(current, payload.Value)
	if problem then
		return false, problem, nil
	end

	local path = table.concat(keys, ".")
	local edited, ok, message = callBackups("Edit", executor, userId, slot, path, nextValue)
	local text = if type(message) == "string" then message else nil
	if not edited or not ok then
		return false, text or "The backup could not be edited.", nil
	end
	AuditLog.Record(executor, "backup:edit", `{describeUser(userId)} slot {slot} {path}: {tostring(current)} -> {tostring(nextValue)}`)
	return true, text or `{path}: {tostring(current)} -> {tostring(nextValue)}`, nil
end

function Handlers.BackupRestore(executor: Player, payload: Payload): (boolean, string, any?)
	local userId = readUserId(payload.UserId)
	local slot = readSlot(payload.Slot)
	if not userId or not slot then
		return false, "Pick a user and one of their backups.", nil
	elseif not canChange(executor, userId) then
		AuditLog.Record(executor, "denied", `backup:restore {describeUser(userId)}`)
		return false, "You cannot restore that player.", nil
	elseif not getBackups() then
		return false, UNAVAILABLE, nil
	end

	-- First request: nothing happens yet, the menu is given a token to send back.
	local pending = pendingRestores[executor]
	local confirmed = pending ~= nil
		and type(payload.Token) == "string"
		and payload.Token == pending.Token
		and pending.UserId == userId
		and pending.Slot == slot
		and os.clock() < pending.Expires
	if not pending or not confirmed then
		local token = HttpService:GenerateGUID(false)
		pendingRestores[executor] = { Token = token, UserId = userId, Slot = slot, Expires = os.clock() + RESTORE_CONFIRM_SECONDS }
		return true,
			`Restore {describeUser(userId)} from backup {slot}? Their current save is replaced. Confirm within {RESTORE_CONFIRM_SECONDS} seconds.`,
			{ Confirm = token }
	end
	pendingRestores[executor] = nil

	if not heavyLimiter:Consume(executor, 2) then
		return false, BUSY, nil
	end
	local called, ok, message = callBackups("RestorePlayer", executor, userId, slot)
	local text = if type(message) == "string" then message else nil
	if not called or not ok then
		AuditLog.Record(executor, "backup:restore", `{describeUser(userId)} slot {slot}: FAILED`)
		return false, text or "The restore failed.", nil
	end
	AuditLog.Record(executor, "backup:restore", `{describeUser(userId)} slot {slot}`)
	return true, text or `Restored {describeUser(userId)} from backup {slot}.`, nil
end

--[[
	Closes THIS server after a countdown. Nobody is targeted, so the menu's role is all it
	takes. The reason is what the players are told: ServerPolicyService cleans it, has it
	filtered and writes the audit entry (with the reason as it was typed).
]]
function Handlers.Shutdown(executor: Player, payload: Payload): (boolean, string, any?)
	local seconds = payload.Seconds
	local reason = payload.Reason
	if type(seconds) ~= "number" or seconds ~= seconds then
		return false, "Type the countdown in seconds.", nil
	elseif reason ~= nil and (type(reason) ~= "string" or #reason > MAX_TEXT_LENGTH) then
		return false, `A reason is a text of at most {MAX_TEXT_LENGTH} characters.`, nil
	end
	local ok, policy = pcall(Knit.GetService, "ServerPolicyService")
	if not ok or not policy then
		return false, "This server cannot be shut down from the menu.", nil
	end

	local countdown = math.floor(math.clamp(seconds, MIN_SHUTDOWN_SECONDS, MAX_SHUTDOWN_SECONDS))
	local started, shown = policy:Shutdown(countdown, false, executor, reason)
	if not started then
		return false, "This server is already shutting down.", nil
	end
	local typed = type(reason) == "string" and string.match(reason, "%S") ~= nil
	return true,
		`This server shuts down in {countdown} seconds. {if shown
			then `Reason shown: {shown}`
			elseif typed then "The reason could not be filtered: none is shown."
			else "No reason is shown."}`,
		nil
end

function StaffActions.Run(executor: Player, action: unknown, payload: unknown): (boolean, string, any?)
	if not Permissions.Has(executor, REQUIRED_ROLE) then
		return false, StaffActions.Unknown, nil
	end
	local handler = if type(action) == "string" and #action <= MAX_ACTION_LENGTH then rawget(Handlers, action) else nil
	if not handler then
		return false, StaffActions.Unknown, nil
	end

	local ok, success, message, result = pcall(handler, executor, if type(payload) == "table" then payload else {})
	if not ok then
		warn(`[StaffActions] {tostring(action)} failed: {tostring(success)}`)
		return false, "The request failed (see the server output).", nil
	end
	return success, message, result
end

function StaffActions.Forget(player: Player)
	heavyLimiter:Forget(player)
	pendingRestores[player] = nil
end

return StaffActions
