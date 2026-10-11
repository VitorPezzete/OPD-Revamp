--!strict
--[[
	Developer menu, drawn with Iris (immediate mode: what is visible of the window is
	described again every frame while it is open, so there is no UI state to keep in sync).

	CLIENT code kept on the server. This folder (Server.StaffClient.Dev) is never
	replicated: DevService hands a copy to an authorised player only (StaffDelivery puts
	it in that player's PlayerGui) and Client.Modules.MenuLoader runs the copy's Main with
	the service's remote mirror and the server's answer:

		access.Key       Enum.KeyCode name that toggles the menu (F4)
		access.Catalog   names and ranges of fruits, weapons, enemies...

	The key toggles it; without a keyboard, a "DEV" button on touch screens and holding
	View / Select on a gamepad do (Client.Modules.IrisHost). The menu holds no power of
	its own, every button is a request the server validates again.

	One tab per category. Every other ModuleScript of this folder is a tab module: it
	returns { [tabName] = build } (see Client.Modules.DevMenuKit) and is picked up without
	being listed anywhere. TAB_ORDER only says where a tab goes; one it does not name is
	added after the others.

		Player    health, haki, god mode, speed, respawn, teleports        DevMenuPlayer
		Stats     skills, experience, perks, records, full reset           DevMenuProgress
		Economy   currencies and tokens                                    DevMenuProgress
		Fruits    slots, eating, affinities, aura, fruit items             DevMenuInventory
		Items     weapons, boxes, compasses, drinks, caches, emotes        DevMenuInventory
		World     clock, seasons, world events, test enemies and bosses    DevMenuWorld
		Combat    test hits, stuns, seals, NPC kills, combat settings      DevMenuPlayer
		UI        screens, HUD, input device, settings, saved data         DevMenuDebug
		Server    server numbers, players, audit log, request log          DevMenuWorld
		          shutting down the servers of a version (on top)          DevMenuShutdown

	A tab that two modules name is drawn by both, in the order of the modules' names.

	Closed, the menu costs nothing: Iris is cycled by Client.Modules.IrisHost (shared with
	the moderator menu) only while a window is up, the snapshot loop is not running and
	the key listener is all that is left. Open, only the selected tab is described.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local IrisHost = require(ReplicatedStorage.Client.Modules.IrisHost)

local FALLBACK_KEY = Enum.KeyCode.F4
local SNAPSHOT_INTERVAL = 1
-- An answered request refreshes the numbers this soon, without waiting for the next poll.
local REFRESH_DELAY = 0.2
local LOG_LIMIT = 30
local SELF = "(me)"
local WINDOW_SIZE = Vector2.new(560, 640)
local WINDOW_POSITION = Vector2.new(60, 60)

local TAB_ORDER = { "Player", "Stats", "Economy", "Fruits", "Items", "World", "Combat", "UI", "Backups", "Server" }

local localPlayer = Players.LocalPlayer

local function build(DevService: any, access: { [string]: any })
	local Iris = IrisHost.Get()
	local catalog: { [string]: any } = access.Catalog
	local keyCode = (Enum.KeyCode :: any)[access.Key]
	local toggleKey: Enum.KeyCode = if typeof(keyCode) == "EnumItem" then keyCode else FALLBACK_KEY

	local opened = Iris.State(false)
	local windowSize = Iris.State(WINDOW_SIZE)
	local windowPosition = Iris.State(WINDOW_POSITION)
	-- Fitted to the screen the first time it opens: while the game loads the viewport is
	-- not the real one yet.
	local fitted = false
	local tabIndex = Iris.State(1)
	-- Who the actions apply to.
	local targetName = Iris.State(SELF)

	local snapshot: { [string]: any }? = nil
	local log: { string } = {}
	local refreshQueued = false
	-- Iris moves the tab selection around while it takes a closed window down.
	local selectedTab = 1
	local restoreTab = false

	local function pushLog(text: string)
		table.insert(log, 1, text)
		if #log > LOG_LIMIT then
			table.remove(log)
		end
	end

	local function getTargetId(): number?
		local name = targetName:get()
		if name == SELF then
			return nil
		end
		local player = Players:FindFirstChild(name)
		return if player and player:IsA("Player") then player.UserId else nil
	end

	local function requestSnapshot()
		local targetId = getTargetId()
		DevService:GetSnapshot(targetId)
			:andThen(function(result: { [string]: any }?)
				-- An answer about somebody who is no longer selected is dropped.
				if result and targetId == getTargetId() then
					snapshot = result
				end
			end)
			:catch(function() end)
	end

	local function queueRefresh()
		if refreshQueued then
			return
		end
		refreshQueued = true
		task.delay(REFRESH_DELAY, function()
			refreshQueued = false
			if opened:get() then
				requestSnapshot()
			end
		end)
	end

	local function runFor(targetId: number?, action: string, ...: any)
		DevService:Execute(action, targetId, ...)
			:andThen(function(ok: boolean, message: string)
				pushLog(`{if ok then "ok" else "FAILED"}  {action}: {message}`)
				queueRefresh()
			end)
			:catch(function(problem: any)
				pushLog(`FAILED  {action}: {tostring(problem)}`)
			end)
	end

	local menu = {
		Iris = Iris,
		Catalog = catalog,
		Service = DevService,
		Run = function(action: string, ...: any)
			runFor(getTargetId(), action, ...)
		end,
		RunFor = runFor,
		GetTargetId = getTargetId,
		GetTargetName = function(): string
			return targetName:get()
		end,
		IsSelf = function(): boolean
			return targetName:get() == SELF
		end,
		GetSnapshot = function(): { [string]: any }?
			return snapshot
		end,
		GetFps = IrisHost.GetFps,
		Log = log,
		PushLog = pushLog,
	}

	-- Each tab makes its states under its own id: Iris names states and widgets after
	-- line numbers alone, which two modules can share.
	local draws: { [string]: () -> () } = {}
	local failures: { [string]: string } = {}
	local tabOrder = table.clone(TAB_ORDER)
	local extraTabs: { string } = {}
	-- By name: two modules may draw in the same tab, and the order must not change from
	-- one run to the next.
	local modules = script.Parent:GetChildren()
	table.sort(modules, function(a: Instance, b: Instance): boolean
		return a.Name < b.Name
	end)
	for _, module in modules do
		if module == script or not module:IsA("ModuleScript") then
			continue
		end
		-- A tab module that fails to load costs its own tabs, not the menu.
		local loaded, tabs = pcall(require :: any, module)
		if not loaded or type(tabs) ~= "table" then
			warn(`[Dev] tab module "{module.Name}" failed: {tostring(tabs)}`)
			continue
		end
		for tabName, builder in tabs do
			Iris.PushId(tabName)
			local built, draw = pcall(builder, menu)
			Iris.PopId()
			if built then
				-- A tab named by two modules shows both, one under the other.
				local earlier = draws[tabName]
				draws[tabName] = if earlier
					then function()
						earlier()
						draw()
					end
					else draw
			else
				warn(`[Dev] tab "{tabName}" failed: {tostring(draw)}`)
			end
			if not table.find(tabOrder, tabName) then
				table.insert(extraTabs, tabName)
			end
		end
	end
	table.sort(extraTabs)
	table.move(extraTabs, 1, #extraTabs, #tabOrder + 1, tabOrder)

	local function drawTarget()
		local names = { SELF }
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer then
				table.insert(names, player.Name)
			end
		end
		if not table.find(names, targetName:get()) then
			targetName:set(SELF)
		end
		local previous = targetName:get()
		Iris.ComboArray({ "Target" }, { index = targetName }, names)
		if targetName:get() ~= previous then
			snapshot = nil
			requestSnapshot()
		end
		Iris.Text({ log[1] or `{toggleKey.Name} closes the menu. Requests are answered here.`, true })
	end

	--[[
		A tab that errors must not take the menu with it: whatever it left open is closed,
		its ids are popped, and the tab shows the error until it is retried.
	]]
	local function drawTab(tabName: string)
		local failure = failures[tabName]
		if failure then
			Iris.Text({ `This tab failed: {failure}`, true, Color3.fromRGB(255, 110, 110) })
			if Iris.Button({ "Retry" }).clicked() then
				failures[tabName] = nil
			end
			return
		end

		local internal = Iris.Internal
		local depth, ids = internal._stackIndex, #internal._pushedIds
		Iris.PushId(tabName)
		local ok, problem = pcall(draws[tabName])
		if not ok then
			while internal._stackIndex > depth do
				Iris.End()
			end
			failures[tabName] = tostring(problem)
			warn(`[Dev] tab "{tabName}" failed: {tostring(problem)}`)
		end
		while #internal._pushedIds > ids do
			Iris.PopId()
		end
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

		local window = Iris.Window({ "Developer" }, { isOpened = opened, size = windowSize, position = windowPosition })
		if window.state.isUncollapsed.value then
			drawTarget()
			Iris.TabBar(nil, { index = tabIndex })
			for index, tabName in tabOrder do
				Iris.Tab({ tabName })
				if draws[tabName] and tabIndex:get() == index then
					drawTab(tabName)
				end
				Iris.End()
			end
			Iris.End()
		end
		Iris.End()
	end)

	IrisHost.Watch(function(): boolean
		return opened:get()
	end)

	-- Numbers are pulled only while the window is open; each opening has its own loop.
	local pollId = 0
	local function startPolling()
		pollId += 1
		local id = pollId
		task.spawn(function()
			while id == pollId and opened:get() do
				requestSnapshot()
				task.wait(SNAPSHOT_INTERVAL)
			end
		end)
	end

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
			startPolling()
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
	IrisHost.AddToggle({
		Label = "DEV",
		Toggle = toggle,
		IsOpen = function(): boolean
			return opened:get()
		end,
	})
end

return build
