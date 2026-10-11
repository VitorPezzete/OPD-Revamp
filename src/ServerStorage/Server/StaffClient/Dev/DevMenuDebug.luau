--!strict
--[[
	Developer menu: the UI tab. Almost all of it is local to the developer's client.

	Screens      open / close any screen UIController knows, by name
	HUD          hide and show the ScreenGuis of PlayerGui
	Device       make the interface believe another input device is in use
	Settings     cycle the developer's own settings (through SettingsService, as the menu does)
	Notify       ask the server for a test notification of each kind
	Saved data   the local profile as a tree, the target's on demand, and the write of one
	             existing value (DevProgressCommands.SetData)
	Client       frame rate, ping, memory, input state

	The device override only fires InputController's signals (and tells InputService):
	screens that follow them switch layout, but the controller's own idea of the device,
	and anything that reads UserInputService.TouchEnabled when it mounts, does not change.
	Touch layouts need Studio's device emulator.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local SettingsConfig = require(ReplicatedStorage.Shared.Configs.SettingsConfig)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local DevMenuKit = require(ReplicatedStorage.Client.Modules.DevMenuKit)

local DEVICES = { "KeyboardMouse", "Gamepad", "Touch" }
-- Deepest level of a data tree that is drawn.
local MAX_DEPTH = 8

local localPlayer = Players.LocalPlayer

local function sortedKeys(dictionary: { [any]: any }): { any }
	local keys = {}
	for key in dictionary do
		table.insert(keys, key)
	end
	table.sort(keys, function(a: any, b: any): boolean
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- Names of every screen module of both interface sets.
local function listScreens(): { string }
	local names: { string } = {}
	local function collect(parent: Instance?)
		local folder = parent and parent:FindFirstChild("Screens")
		for _, module in if folder then folder:GetChildren() else {} do
			if module:IsA("ModuleScript") and not table.find(names, module.Name) then
				table.insert(names, module.Name)
			end
		end
	end
	local ui = ReplicatedStorage.Client:FindFirstChild("UI")
	collect(ui)
	collect(ui and ui:FindFirstChild("Legacy"))
	table.sort(names)
	return names
end

-- A table as collapsible nodes: only what is unfolded is walked.
local function drawTree(Iris: any, key: string, value: any, depth: number)
	if type(value) ~= "table" then
		Iris.Text({ `{key} = {tostring(value)}` })
		return
	end

	local node = Iris.Tree({ key })
	if node.state.isUncollapsed.value then
		if depth >= MAX_DEPTH then
			Iris.Text({ "..." })
		else
			for _, childKey in sortedKeys(value) do
				Iris.PushId(tostring(childKey))
				drawTree(Iris, tostring(childKey), value[childKey], depth + 1)
				Iris.PopId()
			end
		end
	end
	Iris.End()
end

local function buildUI(menu: DevMenuKit.Menu): DevMenuKit.Draw
	local Iris = menu.Iris
	local catalog = menu.Catalog
	local DataController = Knit.GetController("DataController")
	-- Not in every place (PlaceManifest): their sections are empty where they are missing.
	local InputController = Optional.Controller("InputController")
	local SettingsController = Optional.Controller("SettingsController")
	local UIController = Knit.GetController("UIController")

	local screens = listScreens()
	local settings = if SettingsController then sortedKeys(SettingsConfig.Definitions) else {}
	local screenName = Iris.State(screens[1] or "")
	local screenFilter = Iris.State("")
	local notifyKind = Iris.State(catalog.NotifyKinds[1])
	local notifyText = Iris.State("Test notification")
	local dataPath = Iris.State("Combat.Bounty")
	local dataValue = Iris.State("0")

	-- ScreenGuis this menu hid, to put back exactly those.
	local hidden: { [ScreenGui]: boolean } = {}
	local simulated: string? = nil
	local targetData: { [string]: any }? = nil

	local function simulate(kind: string?)
		if not InputController then
			return
		end
		local device = kind or InputController:GetDeviceKind()
		simulated = kind
		InputController.DeviceKindChanged:Fire(device)
		InputController.DeviceChanged:Fire(if kind then kind == "Gamepad" else InputController:IsUsingGamepad())
		Knit.GetService("InputService").Device:Fire(device)
	end

	local function setHidden(gui: ScreenGui, hide: boolean)
		gui.Enabled = not hide
		hidden[gui] = if hide then true else nil
	end

	return function()
		Iris.SeparatorText({ "Screens" })
		DevMenuKit.FilteredCombo(Iris, "Screen", screens, screenName, screenFilter)
		Iris.SameLine()
		if Iris.Button({ "Open" }).clicked() then
			UIController:Open(screenName:get())
		end
		if Iris.Button({ "Close" }).clicked() then
			UIController:Close(screenName:get())
		end
		if Iris.Button({ "Toggle" }).clicked() then
			UIController:Toggle(screenName:get())
		end
		Iris.Text({ if UIController:IsOpen(screenName:get()) then "open" else "closed" })
		Iris.End()
		local openTree = Iris.Tree({ "Open now" })
		if openTree.state.isUncollapsed.value then
			for _, name in screens do
				if UIController:IsOpen(name) then
					Iris.PushId(name)
					Iris.SameLine()
					if Iris.SmallButton({ "Close" }).clicked() then
						UIController:Close(name)
					end
					Iris.Text({ name })
					Iris.End()
					Iris.PopId()
				end
			end
		end
		Iris.End()

		Iris.SeparatorText({ "HUD (this client only)" })
		local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
		local guis: { ScreenGui } = {}
		for _, child in if playerGui then playerGui:GetChildren() else {} do
			if child:IsA("ScreenGui") then
				table.insert(guis, child)
			end
		end
		Iris.SameLine()
		if Iris.Button({ "Hide all" }).clicked() then
			for _, gui in guis do
				if gui.Enabled then
					setHidden(gui, true)
				end
			end
		end
		if Iris.Button({ "Show what I hid" }).clicked() then
			for gui in hidden do
				setHidden(gui, false)
			end
		end
		Iris.End()
		local hudTree = Iris.Tree({ `ScreenGuis ({#guis})` })
		if hudTree.state.isUncollapsed.value then
			for index, gui in guis do
				Iris.PushId(`{gui.Name}-{index}`)
				Iris.SameLine()
				if Iris.SmallButton({ if gui.Enabled then "Hide" else "Show" }).clicked() then
					setHidden(gui, gui.Enabled)
				end
				Iris.Text({ gui.Name })
				Iris.End()
				Iris.PopId()
			end
		end
		Iris.End()

		Iris.SeparatorText({ "Input device (interface signals only)" })
		Iris.SameLine()
		for _, device in DEVICES do
			Iris.PushId(device)
			if Iris.Button({ device }).clicked() then
				simulate(device)
			end
			Iris.PopId()
		end
		if Iris.Button({ "Real device" }).clicked() then
			simulate(nil)
		end
		Iris.End()
		Iris.Text({
			if InputController
				then `Real: {InputController:GetDeviceKind()}   simulated: {simulated or "none"}   controller: {InputController:GetControllerType()} / {InputController:GetControllerMode()}`
				else "This place has no input controller.",
			true,
		})

		Iris.SeparatorText({ "My settings" })
		local settingsTree = Iris.Tree({ "All settings" })
		if settingsTree.state.isUncollapsed.value then
			for _, name in settings do
				Iris.PushId(name)
				Iris.SameLine()
				if Iris.SmallButton({ "Next" }).clicked() then
					SettingsController:Cycle(name):catch(warn)
				end
				Iris.Text({ `{name} = {tostring(SettingsController:Get(name))}` })
				Iris.End()
				Iris.PopId()
			end
		end
		Iris.End()

		Iris.SeparatorText({ "Test notification (sent to me)" })
		Iris.ComboArray({ "Kind" }, { index = notifyKind }, catalog.NotifyKinds)
		Iris.InputText({ "Text" }, { text = notifyText })
		if Iris.Button({ "Send" }).clicked() then
			menu.Run("Notify", notifyText:get(), notifyKind:get())
		end

		Iris.SeparatorText({ "Saved data" })
		Iris.InputText({ "Path", "Combat.Bounty" }, { text = dataPath })
		Iris.InputText({ "Value", "number, true/false or text" }, { text = dataValue })
		local path: string = dataPath:get()
		local current = if menu.IsSelf() then DataController:Get(path) else nil
		Iris.Text({ `Current (me): {if type(current) == "table" then "<table>" else tostring(current)}` })
		if Iris.Button({ "Write path on target" }).clicked() then
			-- The server keeps the type of the existing value; send the closest match.
			local raw: string = dataValue:get()
			local value: any = raw
			if raw == "true" or raw == "false" then
				value = raw == "true"
			elseif tonumber(raw) then
				value = tonumber(raw)
			end
			menu.Run("SetData", path, value)
		end
		if DataController.Data then
			Iris.PushId("mine")
			drawTree(Iris, "My data (live)", DataController.Data, 0)
			Iris.PopId()
		end
		Iris.SameLine()
		if Iris.Button({ "Fetch target data" }).clicked() then
			menu.Service
				:GetReport("Data", menu.GetTargetId())
				:andThen(function(result: { [string]: any }?)
					targetData = result
					if not result then
						menu.PushLog("FAILED  data report: not loaded, denied or too many requests")
					end
				end)
				:catch(function(problem: any)
					menu.PushLog(`FAILED  data report: {tostring(problem)}`)
				end)
		end
		Iris.Text({ "(a copy from when it was fetched)" })
		Iris.End()
		local fetched = targetData
		if fetched then
			Iris.PushId("fetched")
			drawTree(Iris, `Data of {fetched.Name}`, fetched.Data, 0)
			Iris.PopId()
		end

		Iris.SeparatorText({ "Client" })
		Iris.Table({ 2, false, true })
		DevMenuKit.Row(Iris, "Frame rate", `{math.floor(menu.GetFps() + 0.5)} fps`)
		DevMenuKit.Row(Iris, "Ping", `{math.floor(localPlayer:GetNetworkPing() * 1000)} ms`)
		DevMenuKit.Row(Iris, "Memory", `{math.floor(Stats:GetTotalMemoryUsageMb())} MB`)
		DevMenuKit.Row(Iris, "Instances", DevMenuKit.Whole(Stats.InstanceCount))
		local camera = workspace.CurrentCamera
		DevMenuKit.Row(Iris, "Viewport", if camera then `{camera.ViewportSize.X} x {camera.ViewportSize.Y}` else "-")
		DevMenuKit.Row(Iris, "Interface", UIController:GetStyle())
		Iris.End()
	end
end

return {
	UI = buildUI,
} :: DevMenuKit.Tabs
