--!strict
--[[
	Moderator menu, drawn with Iris.

	CLIENT code kept on the server. This folder (Server.StaffClient.Mod) is never
	replicated: AdminService hands a copy to a moderator only (StaffDelivery puts it in
	that player's PlayerGui) and Client.Modules.MenuLoader runs the copy's Main with the
	service's remote mirror and the server's answer:

		access.Key    Enum.KeyCode name that toggles the menu (F3)
		access.Role   the moderator's role, shown in the title

	Above the tabs, who the buttons apply to: a player of this server picked from the
	list, or a user id (or name) typed in, which wins while it is not empty.

		Players   spectate / stop, go to, bring, kick, ban (length and reason), unban,
		          global kick
		Data      the saved data of a player of this server as a tree; a value clicked in
		          the tree can be rewritten. Somebody who is not here only has backups.
		Backups   the backups of a user, online or not: list, view one as the same tree,
		          rewrite a value in it, restore the player from it (asked twice)
		Server    shut this server down after a countdown, with a reason shown to its
		          players (asked twice). The target above plays no part in it.

	The menu holds no power of its own. Every button is one AdminService:Execute request
	(Server.Modules.StaffActions): the server checks the role again, rebuilds every
	argument, refuses a target the moderator does not outrank and writes the audit log.
	The answer is shown under "Output".

	Closed, all that is left is the key listener.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)
local IrisHost = require(ReplicatedStorage.Client.Modules.IrisHost)

type Access = { Key: string, Role: string }
-- A profile or a snapshot as the server sent it, and the value picked in its tree.
type View = { UserId: number, Label: string, Data: { [any]: any }, Slot: string? }
type Editor = { Path: any, Value: any, Kind: string? }

local WINDOW_SIZE = Vector2.new(500, 640)
local WINDOW_POSITION = Vector2.new(60, 60)
local FALLBACK_KEY = Enum.KeyCode.F3
local OUTPUT_LIMIT = 40
local FAILED_COLOR = Color3.fromRGB(255, 110, 110)
local NOTE_COLOR = Color3.fromRGB(170, 170, 170)

local TABS = { "Players", "Data", "Backups", "Server" }

-- Ban lengths offered, in seconds; 0 is a permanent ban.
local DURATIONS = {
	{ Label = "Permanent", Seconds = 0 },
	{ Label = "1 hour", Seconds = 3600 },
	{ Label = "12 hours", Seconds = 12 * 3600 },
	{ Label = "1 day", Seconds = 86400 },
	{ Label = "3 days", Seconds = 3 * 86400 },
	{ Label = "7 days", Seconds = 7 * 86400 },
	{ Label = "30 days", Seconds = 30 * 86400 },
}

-- Deepest level of a data tree that is drawn, and most entries of one table.
local MAX_DEPTH = 10
local MAX_CHILDREN = 250
local MAX_VALUE_LENGTH = 60
-- Seconds the server waits for the second request of a restore.
local RESTORE_SECONDS = 30
-- Countdown of a shutdown, as the server clamps it, and the reason it accepts.
local MIN_SHUTDOWN_SECONDS = 10
local MAX_SHUTDOWN_SECONDS = 3600
local DEFAULT_SHUTDOWN_SECONDS = 60
local MAX_SHUTDOWN_REASON = 120

local localPlayer = Players.LocalPlayer

local function trim(text: string): string
	return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function sortedKeys(dictionary: { [any]: any }): { any }
	local keys = {}
	for key in dictionary do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any): boolean
		if type(a) == "number" and type(b) == "number" then
			return a < b
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- The table holding the value at a dot path and the value's real key (lists are indexed
-- by number), or nil when the path leads nowhere.
local function locate(root: { [any]: any }, path: string): ({ [any]: any }?, any)
	local parent: any = nil
	local key: any = nil
	local current: any = root
	for _, text in string.split(path, ".") do
		if type(current) ~= "table" then
			return nil, nil
		end
		key = text
		if current[key] == nil then
			key = tonumber(text)
			if key == nil or current[key] == nil then
				return nil, nil
			end
		end
		parent = current
		current = current[key]
	end
	return parent, key
end

-- The typed text as a value of the given type; nil when it is not one.
local function parse(kind: string, text: string): any
	if kind == "number" then
		return tonumber(trim(text))
	elseif kind == "boolean" then
		local lowered = string.lower(trim(text))
		if lowered == "true" or lowered == "false" then
			return lowered == "true"
		end
		return nil
	elseif kind == "string" then
		return text
	end
	return nil
end

local function describeTime(seconds: number): string
	if seconds <= 0 then
		return "?"
	end
	return os.date("%Y-%m-%d %H:%M", seconds)
end

return function(service: any, access: Access)
	local Iris = IrisHost.Get()
	local keyCode = (Enum.KeyCode :: any)[access.Key]
	local toggleKey: Enum.KeyCode = if typeof(keyCode) == "EnumItem" then keyCode else FALLBACK_KEY

	-- Iris names states and widgets after line numbers alone: everything of this menu is
	-- made under its own id, apart from the developer menu's.
	Iris.PushId("ModMenu")
	local opened = Iris.State(false)
	local windowSize = Iris.State(WINDOW_SIZE)
	local windowPosition = Iris.State(WINDOW_POSITION)
	local tabIndex = Iris.State(1)

	local playerName = Iris.State(localPlayer.Name)
	local userText = Iris.State("")
	local reason = Iris.State("")
	local durationLabels: { string } = {}
	for _, duration in DURATIONS do
		table.insert(durationLabels, duration.Label)
	end
	local durationLabel = Iris.State(durationLabels[1])

	local dataPath = Iris.State("")
	local dataValue = Iris.State("")
	local backupLabel = Iris.State("")
	local snapshotPath = Iris.State("")
	local snapshotValue = Iris.State("")
	local shutdownReason = Iris.State("")
	local shutdownSeconds = Iris.State(DEFAULT_SHUTDOWN_SECONDS)

	local confirms: { [string]: any } = {}
	for _, key in { "Kick", "Ban", "Unban", "GlobalKick", "DataWrite", "BackupEdit", "Shutdown" } do
		Iris.PushId(key)
		confirms[key] = Iris.State(0)
		Iris.PopId()
	end
	Iris.PopId()

	-- Fitted to the screen the first time it opens: while the game loads the viewport is
	-- not the real one yet.
	local fitted = false
	local output: { string } = { `{toggleKey.Name} closes the menu. Answers are shown here.` }
	local failed = false
	local busy = false
	-- Iris moves the tab selection around while it takes a closed window down.
	local selectedTab = 1
	local restoreTab = false

	local dataView: View? = nil
	local dataEditor: Editor = { Path = dataPath, Value = dataValue, Kind = nil }
	local backupUserId: number? = nil
	local backupEntries: { [string]: string } = {}
	local backupLabels: { string } = {}
	local snapshotView: View? = nil
	local snapshotEditor: Editor = { Path = snapshotPath, Value = snapshotValue, Kind = nil }
	-- A restore the server is waiting to have confirmed.
	local pendingRestore: { Token: string, UserId: number, Slot: string, Expires: number }? = nil

	local function show(ok: boolean, message: any)
		failed = not ok
		output = {}
		for _, line in string.split(tostring(message), "\n") do
			if #output < OUTPUT_LIMIT then
				table.insert(output, line)
			end
		end
		if #output == 0 or (output[1] == "" and #output == 1) then
			output = { if ok then "Done." else "Failed." }
		end
	end

	-- One request at a time; `after` runs with the server's result when there is one.
	local function request(action: string, payload: { [string]: any }, after: ((ok: boolean, result: any) -> ())?)
		if busy then
			return
		end
		busy = true
		service
			:Execute(action, payload)
			:andThen(function(ok: boolean, message: any, result: any)
				show(ok, message)
				if after then
					after(ok, result)
				end
			end)
			:catch(function(problem: any)
				show(false, problem)
			end)
			:finally(function()
				busy = false
			end)
	end

	-- Who the buttons apply to ------------------------------------------------------

	local function selectedPlayer(): Player?
		local player = Players:FindFirstChild(playerName:get())
		return if player and player:IsA("Player") then player else nil
	end

	-- The typed user as a number when it is one, else as text; the picked player when
	-- nothing is typed. The server resolves a name.
	local function targetUser(): any
		local typed = trim(userText:get())
		if typed ~= "" then
			return tonumber(typed) or typed
		end
		local player = selectedPlayer()
		return if player then player.UserId else nil
	end

	-- A user id: typed, of a typed name that is in this server, or of the picked player.
	local function targetUserId(): number?
		local user = targetUser()
		if type(user) == "string" then
			local player = Players:FindFirstChild(user)
			return if player and player:IsA("Player") then player.UserId else nil
		end
		return user
	end

	local function describeTarget(): string
		local user = targetUser()
		if type(user) == "number" then
			local player = Players:GetPlayerByUserId(user)
			return if player then `{player.Name} ({user})` else `user {user} (not in this server)`
		elseif type(user) == "string" then
			return `"{user}"`
		end
		return "nobody"
	end

	-- Spectating ---------------------------------------------------------------------
	-- The server only streams the map around the watched player; the camera is ours.

	local watched: Player? = nil
	local watching: RBXScriptConnection? = nil

	local function setCameraSubject(character: Model?)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local camera = Workspace.CurrentCamera
		if humanoid and camera and camera.CameraSubject ~= humanoid then
			camera.CameraSubject = humanoid
		end
	end

	local function stopWatching()
		if watching then
			watching:Disconnect()
			watching = nil
		end
		if watched then
			watched = nil
			setCameraSubject(localPlayer.Character)
		end
	end

	local function watch(target: Player)
		stopWatching()
		watched = target
		-- Every frame: the watched character may not be streamed in yet, respawns, and
		-- the game's own camera code may take the subject back.
		watching = RunService.Heartbeat:Connect(function()
			if target.Parent ~= Players then
				stopWatching()
				service:Execute("Spectate", {}):catch(function() end)
				return
			end
			setCameraSubject(target.Character)
		end)
	end

	-- Data trees ---------------------------------------------------------------------

	local function pick(editor: Editor, path: string, value: any)
		editor.Path:set(path)
		editor.Value:set(tostring(value))
		editor.Kind = type(value)
	end

	-- A table as collapsible nodes: only what is unfolded is walked. A value is a button
	-- that puts its path in the editor.
	local function drawTree(editor: Editor, label: string, value: any, path: string, depth: number)
		if type(value) ~= "table" then
			local text = tostring(value)
			if #text > MAX_VALUE_LENGTH then
				text = string.sub(text, 1, MAX_VALUE_LENGTH) .. "..."
			end
			if Iris.SmallButton({ `{label} = {text}` }).clicked() then
				pick(editor, path, value)
			end
			return
		end

		local node = Iris.Tree({ label })
		if node.state.isUncollapsed.value then
			if depth >= MAX_DEPTH then
				Iris.Text({ "..." })
			else
				local keys = sortedKeys(value)
				for index, childKey in keys do
					if index > MAX_CHILDREN then
						Iris.Text({ `... and {#keys - MAX_CHILDREN} more` })
						break
					end
					local name = tostring(childKey)
					Iris.PushId(name)
					drawTree(editor, name, value[childKey], if path == "" then name else `{path}.{name}`, depth + 1)
					Iris.PopId()
				end
			end
		end
		Iris.End()
	end

	-- The editor under a tree. Returns the path and the value to send when it is confirmed.
	local function drawEditor(editor: Editor, view: View, confirm: any, button: string): (string?, any)
		Iris.InputText({ "Path", "click a value in the tree" }, { text = editor.Path })
		Iris.InputText({ "New value", "number, true/false or text" }, { text = editor.Value })
		if not DevMenuKit.Confirm(Iris, button, confirm) then
			return nil, nil
		end

		local path = trim(editor.Path:get())
		local parent, key = locate(view.Data, path)
		local current = if parent then parent[key] else nil
		local kind = type(current)
		if kind ~= "number" and kind ~= "boolean" and kind ~= "string" then
			show(false, "Click a single value in the tree first (a number, true/false or text).")
			return nil, nil
		end
		local value = parse(kind, editor.Value:get())
		if value == nil then
			show(false, `That value is a {if kind == "string" then "text" else kind}.`)
			return nil, nil
		end
		return path, value
	end

	-- What was written is shown in the copy at once; the server's line says what was saved.
	local function applyLocally(view: View, path: string, value: any)
		local parent, key = locate(view.Data, path)
		if parent then
			parent[key] = value
		end
	end

	-- Tabs ---------------------------------------------------------------------------

	local function drawPlayers()
		Iris.SeparatorText({ "Watch and move (a player of this server)" })
		Iris.SameLine()
		if Iris.Button({ "Spectate" }).clicked() then
			local userId = targetUserId()
			local target = if userId then Players:GetPlayerByUserId(userId) else nil
			if not target or target == localPlayer then
				show(false, "Pick another player of this server.")
			else
				request("Spectate", { Player = target.UserId }, function(ok: boolean)
					if ok then
						watch(target)
					end
				end)
			end
		end
		if Iris.Button({ "Stop spectating" }).clicked() then
			stopWatching()
			if busy then
				-- Never dropped behind another request: the server stops streaming for us.
				service:Execute("Spectate", {}):catch(function() end)
			else
				request("Spectate", {})
			end
		end
		if Iris.Button({ "Go to" }).clicked() then
			request("Goto", { Player = targetUserId() })
		end
		if Iris.Button({ "Bring" }).clicked() then
			request("Bring", { Player = targetUserId() })
		end
		Iris.End()
		local spectated = watched
		if spectated then
			Iris.Text({ `Spectating {spectated.Name}.`, true, NOTE_COLOR })
		end

		Iris.SeparatorText({ "Kick and ban" })
		Iris.InputText({ "Reason", "kept in the audit log; a ban shows it to the player" }, { text = reason })
		Iris.ComboArray({ "Ban length" }, { index = durationLabel }, durationLabels)
		Iris.SameLine()
		if DevMenuKit.Confirm(Iris, "Kick", confirms.Kick) then
			request("Kick", { Player = targetUserId(), Reason = reason:get() })
		end
		if DevMenuKit.Confirm(Iris, "Ban", confirms.Ban) then
			local seconds = 0
			for _, duration in DURATIONS do
				if duration.Label == durationLabel:get() then
					seconds = duration.Seconds
				end
			end
			request("Ban", { Player = targetUser(), Reason = reason:get(), Duration = seconds })
		end
		if DevMenuKit.Confirm(Iris, "Unban", confirms.Unban) then
			request("Unban", { Player = targetUser() })
		end
		if DevMenuKit.Confirm(Iris, "Global kick", confirms.GlobalKick) then
			request("GlobalKick", { Player = targetUser() })
		end
		Iris.End()
		Iris.Text({
			"Kick needs a player of this server. Ban, unban and global kick reach any user, online or not.",
			true,
			NOTE_COLOR,
		})
	end

	local function drawData()
		Iris.SameLine()
		if Iris.Button({ "Load data" }).clicked() then
			local userId = targetUserId()
			if not userId then
				show(false, "Pick a player or type a user id.")
			else
				request("DataRead", { UserId = userId }, function(ok: boolean, result: any)
					dataView = nil
					dataEditor.Kind = nil
					if ok and type(result) == "table" and result.Online and type(result.Data) == "table" then
						dataView = { UserId = result.UserId, Label = `{result.Name} ({result.UserId})`, Data = result.Data }
					end
				end)
			end
		end
		if Iris.Button({ "Close" }).clicked() then
			dataView = nil
		end
		Iris.End()

		local view = dataView
		if not view then
			Iris.Text({
				"The data of a player of this server, as it is in memory. Somebody who is not here cannot be loaded: use the Backups tab.",
				true,
				NOTE_COLOR,
			})
			return
		end

		Iris.Text({ "A copy from when it was loaded. Click a value to edit it.", true, NOTE_COLOR })
		Iris.PushId("live")
		drawTree(dataEditor, `Data of {view.Label}`, view.Data, "", 0)
		Iris.PopId()

		Iris.SeparatorText({ "Write one value" })
		local path, value = drawEditor(dataEditor, view, confirms.DataWrite, "Write value")
		if path then
			request("DataWrite", { UserId = view.UserId, Path = path, Value = value }, function(ok: boolean)
				if ok then
					applyLocally(view, path, value)
				end
			end)
		end
	end

	local function selectedSlot(): string?
		return backupEntries[backupLabel:get()]
	end

	local function drawBackups()
		Iris.SameLine()
		if Iris.Button({ "List backups" }).clicked() then
			local userId = targetUserId()
			if not userId then
				show(false, "Pick a player or type a user id.")
			else
				request("BackupList", { UserId = userId }, function(ok: boolean, result: any)
					backupUserId = nil
					backupEntries = {}
					backupLabels = {}
					snapshotView = nil
					pendingRestore = nil
					if not ok or type(result) ~= "table" or type(result.Entries) ~= "table" then
						return
					end
					backupUserId = result.UserId
					for _, entry in result.Entries do
						local label = `{entry.Kind}  {describeTime(entry.Time)}  [{entry.Slot}]`
						backupEntries[label] = entry.Slot
						table.insert(backupLabels, label)
					end
					backupLabel:set(backupLabels[1] or "")
				end)
			end
		end
		Iris.End()

		local userId = backupUserId
		if not userId then
			Iris.Text({ "The backups of a user, in this server or not.", true, NOTE_COLOR })
			return
		elseif #backupLabels == 0 then
			Iris.Text({ `User {userId} has no backups.`, true, NOTE_COLOR })
			return
		end

		Iris.Text({ `Backups of user {userId}, newest first.` })
		if not table.find(backupLabels, backupLabel:get()) then
			backupLabel:set(backupLabels[1])
		end
		Iris.ComboArray({ "Backup" }, { index = backupLabel }, backupLabels)
		local slot = selectedSlot()
		if not slot then
			return
		end

		Iris.SameLine()
		if Iris.Button({ "View" }).clicked() then
			request("BackupRead", { UserId = userId, Slot = slot }, function(ok: boolean, result: any)
				snapshotView = nil
				snapshotEditor.Kind = nil
				if ok and type(result) == "table" and type(result.Data) == "table" then
					snapshotView = { UserId = result.UserId, Slot = result.Slot, Label = `{result.UserId} [{result.Slot}]`, Data = result.Data }
				end
			end)
		end
		-- Asked twice: this click only makes the server hold the restore for a moment and
		-- answer with a token; "Yes, restore" below sends it back.
		if Iris.Button({ "Restore player from this backup" }).clicked() then
			request("BackupRestore", { UserId = userId, Slot = slot }, function(ok: boolean, result: any)
				pendingRestore = nil
				if ok and type(result) == "table" and type(result.Confirm) == "string" then
					pendingRestore = { Token = result.Confirm, UserId = userId, Slot = slot, Expires = os.clock() + RESTORE_SECONDS }
				end
			end)
		end
		Iris.End()

		local pending = pendingRestore
		if pending and (os.clock() > pending.Expires or pending.UserId ~= userId or pending.Slot ~= slot) then
			pendingRestore = nil
			pending = nil
		end
		if pending then
			Iris.Text({
				`This replaces the current save of user {pending.UserId} with backup [{pending.Slot}].`,
				true,
				FAILED_COLOR,
			})
			Iris.SameLine()
			if Iris.Button({ "Yes, restore" }).clicked() then
				pendingRestore = nil
				request("BackupRestore", { UserId = pending.UserId, Slot = pending.Slot, Token = pending.Token })
			end
			if Iris.Button({ "Cancel" }).clicked() then
				pendingRestore = nil
			end
			Iris.End()
		end

		local view = snapshotView
		if not view or view.UserId ~= userId then
			return
		end
		Iris.PushId("snapshot")
		drawTree(snapshotEditor, `Backup {view.Label}`, view.Data, "", 0)
		Iris.PopId()

		Iris.SeparatorText({ `Edit one value of backup [{view.Slot}]` })
		local path, value = drawEditor(snapshotEditor, view, confirms.BackupEdit, "Edit backup value")
		if path then
			request("BackupEdit", { UserId = view.UserId, Slot = view.Slot, Path = path, Value = value }, function(ok: boolean)
				if ok then
					applyLocally(view, path, value)
				end
			end)
		end
	end

	local function drawServer()
		Iris.SeparatorText({ "Shut down this server" })
		Iris.InputText({ "Reason", "shown to every player, filtered" }, { text = shutdownReason })
		Iris.InputNum(
			{ "Countdown (seconds)", 10, MIN_SHUTDOWN_SECONDS, MAX_SHUTDOWN_SECONDS },
			{ number = shutdownSeconds }
		)
		if DevMenuKit.Confirm(Iris, "Shut down this server", confirms.Shutdown) then
			local text = trim(shutdownReason:get())
			if #text > MAX_SHUTDOWN_REASON then
				show(false, `The reason is longer than {MAX_SHUTDOWN_REASON} characters.`)
			else
				local seconds = math.clamp(math.floor(shutdownSeconds:get()), MIN_SHUTDOWN_SECONDS, MAX_SHUTDOWN_SECONDS)
				request("Shutdown", { Seconds = seconds, Reason = text })
			end
		end
		Iris.Text({
			"Everybody in this server is warned during the countdown, then kicked; nobody can join it afterwards. A countdown cannot be cancelled. Other servers are not touched.",
			true,
			NOTE_COLOR,
		})
	end

	local draws: { [string]: () -> () } = { Players = drawPlayers, Data = drawData, Backups = drawBackups, Server = drawServer }

	local function drawTarget()
		local names: { string } = {}
		for _, player in Players:GetPlayers() do
			table.insert(names, player.Name)
		end
		table.sort(names)
		if not table.find(names, playerName:get()) then
			playerName:set(localPlayer.Name)
		end
		Iris.ComboArray({ "Player" }, { index = playerName }, names)
		Iris.InputText({ "User", "user id or name: used instead of the list" }, { text = userText })
		Iris.Text({ `Target: {describeTarget()}`, true, NOTE_COLOR })
	end

	Iris:Connect(function()
		if not opened:get() then
			return
		end
		if restoreTab then
			restoreTab = false
			tabIndex:set(selectedTab)
		else
			selectedTab = math.max(1, tabIndex:get())
		end

		Iris.PushId("ModMenu")
		local window = Iris.Window({ `Moderator ({access.Role})` }, { isOpened = opened, size = windowSize, position = windowPosition })
		if window.state.isUncollapsed.value then
			drawTarget()
			Iris.TabBar(nil, { index = tabIndex })
			for index, tabName in TABS do
				Iris.Tab({ tabName })
				if tabIndex:get() == index then
					Iris.PushId(tabName)
					draws[tabName]()
					Iris.PopId()
				end
				Iris.End()
			end
			Iris.End()

			Iris.SeparatorText({ if busy then "Output (waiting for the server...)" else "Output" })
			for _, line in output do
				Iris.Text({ line, true, if failed then FAILED_COLOR else nil })
			end
		end
		Iris.End()
		Iris.PopId()
	end)

	IrisHost.Watch(function(): boolean
		return opened:get()
	end)

	local function toggle()
		opened:set(not opened:get())
		if opened:get() then
			if not fitted then
				fitted = true
				local size, position = IrisHost.Fit(WINDOW_SIZE)
				windowSize:set(size)
				windowPosition:set(position)
			end
			restoreTab = true
			IrisHost.Wake()
		end
	end

	UserInputService.InputBegan:Connect(function(input: InputObject)
		-- Works while typing in the menu too, so gameProcessed is not checked; a focused
		-- chat or game text box still keeps the key.
		if input.KeyCode ~= toggleKey or UserInputService:GetFocusedTextBox() then
			return
		end
		toggle()
	end)
	-- Without a keyboard: a "MOD" button on touch screens, View / Select held with L1 on
	-- a gamepad (the developer menu is the one that opens without a modifier).
	IrisHost.AddToggle({
		Label = "MOD",
		Toggle = toggle,
		IsOpen = function(): boolean
			return opened:get()
		end,
		Modifier = Enum.KeyCode.ButtonL1,
	})
end
