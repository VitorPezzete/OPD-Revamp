--!strict
--[[
	Developer menu: the Backups tab (server side: DevBackupCommands, BackupService).

	One player   the snapshots of a user id (in this server or not), and a restore from one
	Everybody    the global rollback keypoint: set it to a day, see it, remove it

	Unlike the other tabs this one works on a user id, not on the menu's target: the
	target only fills the id box. Dates and times are UTC, as the snapshots are.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

type Entry = { Slot: string, Kind: string, Day: number, Time: number }

local SECONDS_PER_DAY = 86400
-- 7 dailies and 4 weeklies at most (BackupConfig); a few spare rows cost nothing.
local MAX_ROWS = 16
local MAX_USER_ID = 2 ^ 53

local function formatDay(day: number): string
	return os.date("!%Y-%m-%d", day * SECONDS_PER_DAY)
end

-- BackupList's answer: "<user id>: D20736@1791590400 W20730@1791072000 ...", newest first.
local function parseEntries(message: string): { Entry }
	local entries: { Entry } = {}
	for letter, day, time in string.gmatch(message, "([DW])(%d+)@(%d+)") do
		table.insert(entries, {
			Slot = letter .. day,
			Kind = if letter == "D" then "Daily" else "Weekly",
			Day = tonumber(day) or 0,
			Time = tonumber(time) or 0,
		})
	end
	return entries
end

local function buildBackups(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local settings = menu.Catalog.Backups or {}
	local rollbackDays: number = settings.RollbackDays or 35
	local phrase: string = settings.RollbackPhrase or "ROLLBACK"

	local userIdText = Iris.State("")
	local restoreArmed: { any } = {}
	for index = 1, MAX_ROWS do
		Iris.PushId(`row-{index}`)
		restoreArmed[index] = Iris.State(0)
		Iris.PopId()
	end
	local dayChoice = Iris.State("")
	local typed = Iris.State("")
	local rollbackArmed = Iris.State(0)
	local clearArmed = Iris.State(0)

	-- The last list the server answered with, and whose it is.
	local entries: { Entry } = {}
	local listedId: number? = nil
	local status = "Enter a user id and list its snapshots."
	local asking = false

	-- Day labels of the picker, rebuilt when the day changes.
	local labels: { string } = {}
	local dayOfLabel: { [string]: number } = {}
	local labelsDay = -1

	local function readUserId(): number?
		local id = tonumber(userIdText:get())
		if not id or id % 1 ~= 0 or id <= 0 or id >= MAX_USER_ID then
			return nil
		end
		return id
	end

	local function list(userId: number)
		asking = true
		status = "Asking the backup store..."
		-- Called directly instead of menu.RunFor: the answer is the list itself.
		menu.Service
			:Execute("BackupList", nil, userId)
			:andThen(function(ok: boolean, message: string)
				asking = false
				menu.PushLog(`{if ok then "ok" else "FAILED"}  BackupList: {message}`)
				if not ok then
					status = `Failed: {message}`
					return
				end
				entries = parseEntries(message)
				listedId = userId
				status = if #entries == 0 then `{userId} has no snapshot.` else `{#entries} snapshots of {userId}, newest first.`
				for _, armed in restoreArmed do
					armed:set(0)
				end
			end)
			:catch(function(problem: any)
				asking = false
				status = `Failed: {tostring(problem)}`
			end)
	end

	local function refreshLabels(today: number)
		if today == labelsDay then
			return
		end
		labelsDay = today
		labels = {}
		dayOfLabel = {}
		for age = 0, rollbackDays do
			local day = today - age
			local ageText = if age == 0 then "today" elseif age == 1 then "yesterday" else age .. " days ago"
			local label = `{formatDay(day)} ({ageText})`
			table.insert(labels, label)
			dayOfLabel[label] = day
		end
	end

	return function()
		local data = menu.GetSnapshot()

		Iris.SeparatorText({ "One player" })
		Iris.SameLine()
		if Iris.SmallButton({ "Use target" }).clicked() then
			userIdText:set(tostring(menu.GetTargetId() or Players.LocalPlayer.UserId))
		end
		if Iris.SmallButton({ "List snapshots" }).clicked() and not asking then
			local userId = readUserId()
			if userId then
				list(userId)
			else
				status = "That is not a user id."
			end
		end
		Iris.InputText({ "User id", "digits only" }, { text = userIdText })
		Iris.End()
		Iris.Text({ status, true })

		local userId = listedId
		if userId then
			for index, entry in entries do
				if index > MAX_ROWS then
					break
				end
				Iris.PushId(entry.Slot)
				Iris.SameLine()
				if DevMenuKit.Confirm(Iris, "Restore", restoreArmed[index]) then
					menu.RunFor(nil, "BackupRestore", userId, entry.Slot)
				end
				Iris.Text({
					`{entry.Kind}  {formatDay(entry.Day)}  (taken {os.date("!%Y-%m-%d %H:%M", entry.Time)} UTC, slot {entry.Slot})`,
				})
				Iris.End()
				Iris.PopId()
			end
			if #entries > 0 then
				Iris.Text({
					"A snapshot is the data as it loaded that day, before anything was played. Restoring kicks the player if they are online (any server); otherwise it applies when they next join. Purchase receipts are kept.",
					true,
				})
			end
		end

		Iris.SeparatorText({ "Everybody (global rollback)" })
		local keypoint = if data then data.BackupKeypoint else nil
		Iris.Text({
			if not data then "Waiting for the server..." elseif keypoint then `In force: {keypoint}` else "No global rollback in force.",
			true,
		})

		refreshLabels(if data and type(data.BackupDay) == "number" then data.BackupDay else Workspace:GetServerTimeNow() // SECONDS_PER_DAY)
		if not dayOfLabel[dayChoice:get()] then
			dayChoice:set(labels[1])
		end
		Iris.ComboArray({ "Back to the start of" }, { index = dayChoice }, labels)
		Iris.InputText({ "Confirmation", `type {phrase}` }, { text = typed })

		local day = dayOfLabel[dayChoice:get()]
		if typed:get() ~= phrase then
			Iris.Text({ `Type {phrase} above to unlock the rollback of EVERY player to {formatDay(day)}.`, true })
		elseif DevMenuKit.Confirm(Iris, `Roll EVERYBODY back to the start of {formatDay(day)}`, rollbackArmed) then
			menu.RunFor(nil, "BackupRollback", day, typed:get())
			typed:set("")
		end
		Iris.Text({
			"Every profile goes back to how it was when that day began, the next time it loads; online players are kicked, in every server. Profiles created after that day are reset.",
			true,
		})

		Iris.SameLine()
		if Iris.Button({ "Show the keypoint" }).clicked() then
			menu.RunFor(nil, "BackupKeypoint")
		end
		if DevMenuKit.Confirm(Iris, "Remove the keypoint", clearArmed) then
			menu.RunFor(nil, "BackupClearRollback")
		end
		Iris.End()
		Iris.Text({ "Removing it stops the rollback for profiles it has not reached yet; restores already made stay.", true })
	end
end

return {
	Backups = buildBackups,
} :: DevMenuKit.Tabs
