--!strict
--[[
	Menu tab "Settings": three pages.

	General        player list, join messages, hide bounty, auto menu, music volume, the
	               settings reset button (two clicks: every option back to its default)
	               and the stat reset button (its own screen, "ResetStats").
	Optimization   damage numbers, hitbox, damage counter, fog, sun mode and observation
	               mode, and Fast Mode (the legacy low graphics: Off, On, Extreme).
	Keybinds       two lists behind a device switch: Keyboard and Controller.

	Every control shows the replicated Settings table; a click only asks
	SettingsController for the next value (the server validates and stores it), so the tab
	shows what is saved, not what was clicked. What a setting does is applied elsewhere.
	A setting's description sits under its name and the row grows to hold it (Kit.Row).

	The General page also holds the control layout (Settings.Control_Layout: "Default",
	"Auto" or "Custom") for players without a mouse: the row shows on a touch screen or
	while a gamepad is the device in use, its button steps through the three, and while the
	layout is "Custom" its "Customize" button closes the menu tab and opens the controls
	editor (screen "ControlsEditor").

	Keybinds. The two devices are separate layouts and nothing done to one touches the
	other; each is saved in the player's profile (HotkeyService), so it is there again on
	the next join, in every place.
	- Keyboard: keys are not typed. Clicking a first key selects it, clicking a second one
	  swaps the keys of the two actions.
	- Controller: the layout switch (Classic / Advanced), then every action a gamepad can
	  trigger in that layout with the picture of its button - the player's own, not a
	  fixed list. Each layout has its own bindings. "Change" on a row waits for the next
	  press of a gamepad button (InputController:CapturePadButton: that press goes nowhere
	  else) and asks the server to bind it; View / Select or a few seconds without a press
	  cancel. A button another action of the same context holds trades places with it (the
	  server decides, see InputConfig), and a button the engine keeps is refused. Two
	  actions that do share a button (a profile older than these rules) are both marked.
	  The page is driven with the pad itself: the D-pad moves, A presses "Change".
	"Defaults" restores the list in view and nothing else.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local UIConfig = require(ReplicatedStorage.Shared.Configs.UIConfig)
local SettingsConfig = require(ReplicatedStorage.Shared.Configs.SettingsConfig)
local TradeConfig = require(ReplicatedStorage.Shared.Configs.TradeConfig)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local UI = require(ReplicatedStorage.Client.UI.Components)

local Kit = require(script.Parent.Kit)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

local peek = Fusion.peek

local RESET_SCREEN = "ResetStats"
-- The control layout row: its setting, the value that has an editor, and the editor's screen.
local LAYOUT_SETTING = ControlsConfig.LayoutSetting
local CUSTOM_LAYOUT = ControlsConfig.Layouts.Custom
local DEFAULT_LAYOUT = ControlsConfig.Layouts.Default
local EDITOR_SCREEN = "ControlsEditor"
local CONTROL_LAYOUT_HINT = "Touch buttons. Default: as they are. Auto: each button behaves by what its action is "
	.. "(a single cast on touch, hold to charge, tap on and off for what lasts). "
	.. "Custom: move, resize and set each button yourself, and offset the camera and the aim."
local CUSTOMIZE_BUTTON = UDim2.fromOffset(130, 32)
-- Settings.Camera_Lock: how hard the camera is pulled towards the locked target.
local CAMERA_LOCK_LABELS = { [0] = "Off", [1] = "Soft", [2] = "Medium", [3] = "Strong" }
local CAMERA_LOCK_HINT = "Gamepad and touch: keeps the camera on a target. Switched with the Camera Lock button "
	.. "of your controller (Keybinds) or the lock button on the screen."
local ROOT_LOCK_HINT = "Gamepad and touch only: your character always faces where the camera looks."
local AUTO_MENU_HINT = "Closes the shop when you move."
local AIM_ASSIST_HINT = "Gamepad and touch only."
local TRADE_HINT = "Lets other players invite you to trade."
local CHARGE_HINT = "Chargeable abilities start on one press and release on the next, instead of holding."
local UI_STYLE_HINT = "Rework is the new interface. Legacy is the old game's, with the new health bar and player list."
local UI_SCALE_HINT = "Enlarges the whole interface."
local STATS_HINT = "Wipes your stats, Beri, fruits and items."
-- What SettingsService.Client:Reset does and leaves alone.
local RESET_SETTINGS = "Reset Settings"
local RESET_SETTINGS_CONFIRM = "Click again to reset"
local RESET_SETTINGS_HINT = "Puts every option back to its default. Keybinds, UI Style and your custom button layout stay."
-- Seconds the reset button waits for its second click.
local RESET_CONFIRM_SECONDS = 4
-- What StatResetService:ResetStats wipes (the legacy tip said "Resets ALL data.").
local RESET_TIP = "Resets your combat stats, Haki, Beri, bounty and kills, and removes your devil fruits and items."

local GENERAL = "General"
local OPTIMIZATION = "Optimization"
local KEYBINDS = "Keybinds"

local WINDOW_SIZE = Vector2.new(700, 700)
local TABS_HEIGHT = 38
local VALUE_BUTTON = UDim2.fromOffset(170, 32)
-- The strip above a keybind list: two lines of help beside the "Defaults" button.
local BAR_HEIGHT = 46
local DEFAULTS_SIZE = Vector2.new(140, 32)
local DEVICE_TABS_HEIGHT = 32
local CHANGE_BUTTON = UDim2.fromOffset(120, 30)

-- The device switch of the Keybinds page.
local KEYBOARD = "Keyboard"
local CONTROLLER = "Controller"
local KEYBOARD_DEVICE: InputConfig.Device = "KB"

local KEYBOARD_HINT = "Click a key, then another one: the two actions swap keys."
local KEYBOARD_SELECTED_HINT = "Now click the key to swap it with."
local PAD_HINT = "Choose Change, then press the new button. A button in use trades places."
local SAVING = "Saving..."
local PAD_CANCELLED = "Nothing changed."
local PAD_REFUSED = "That button cannot go there: it is needed where it is."
local PAD_SHARED = "shares its button"

-- Rows of the keyboard list, in order. A row without Rebind only shows its key (it never
-- had code behind it). The keys "Defaults" restores are InputConfig's.
local KEYBINDS_LIST: { { Action: string, Label: string, Rebind: boolean } } = {
	{ Action = "DF1A", Label = "Devil Fruit Ability 1", Rebind = true },
	{ Action = "DF1B", Label = "Devil Fruit Ability 2", Rebind = true },
	{ Action = "DF1C", Label = "Devil Fruit Ability 3", Rebind = true },
	{ Action = "DF1D", Label = "Devil Fruit Ability 4", Rebind = true },
	{ Action = "DF1E", Label = "Devil Fruit Ability 5", Rebind = true },
	{ Action = "DF1F", Label = "Devil Fruit Ability 6", Rebind = true },
	{ Action = "DF2A", Label = "Devil Fruit Ability 7", Rebind = true },
	{ Action = "DF2B", Label = "Devil Fruit Ability 8", Rebind = true },
	{ Action = "DF2C", Label = "Devil Fruit Ability 9", Rebind = true },
	{ Action = "DF2D", Label = "Devil Fruit Ability 10", Rebind = true },
	{ Action = "DF2E", Label = "Devil Fruit Ability 11", Rebind = true },
	{ Action = "DF2F", Label = "Devil Fruit Ability 12", Rebind = true },
	{ Action = "Dash", Label = "Dash", Rebind = true },
	{ Action = "Haki", Label = "Haki", Rebind = true },
	{ Action = "Shave", Label = "Shave", Rebind = true },
	{ Action = "Observation", Label = "Observation", Rebind = true },
	{ Action = "Emotes", Label = "Emotes Menu", Rebind = true },
	{ Action = "Conq", Label = "Conqueror's Haki", Rebind = true },
	{ Action = "SpFn", Label = "Special Attack", Rebind = true },
	{ Action = "Unassigned1", Label = "Unassigned", Rebind = true },
	{ Action = "Unassigned2", Label = "Unassigned", Rebind = true },
	{ Action = "Unassigned3", Label = "Unassigned", Rebind = true },
}
-- An action whose system is switched off (InputConfig.IsEnabled) has no row.
for index = #KEYBINDS_LIST, 1, -1 do
	if not InputConfig.IsEnabled(KEYBINDS_LIST[index].Action) then
		table.remove(KEYBINDS_LIST, index)
	end
end

-- Settings.ControllerType as the menu calls it.
local LAYOUT_LABELS: { [string]: string } = { Legacy = "Classic", Shortcut = "Advanced" }

---------------------------------------------------------------------------------
-- Keybind requests

local warned = false

-- The key in force for an action on a device, from the replicated Hotkeys table.
local function readKey(hotkeys: any, device: InputConfig.Device, action: string): string
	local row = if type(hotkeys) == "table" then hotkeys[action] else nil
	return InputConfig.ReadKey(device, action, if type(row) == "table" then row[device] else nil)
end

local function currentKey(device: InputConfig.Device, action: string): string
	return readKey(Knit.GetController("DataController"):Get("Hotkeys"), device, action)
end

-- Yields. Calls a method of HotkeyService; true when the server accepted the request.
local function request(method: string, ...: any): boolean
	local found, service = pcall(Knit.GetService, "HotkeyService")
	if not found then
		if not warned then
			warned = true
			warn("[UI] HotkeyService is not available: keybinds cannot be changed")
		end
		return false
	end

	local arguments = table.pack(...)
	local ok, accepted = pcall(function()
		local resolved, result = service[method](service, table.unpack(arguments, 1, arguments.n)):await()
		return resolved and result == true
	end)
	return ok and accepted == true
end

local function setKey(action: string, device: InputConfig.Device, key: string): boolean
	return request("SetHotkey", action, device, key)
end

local function resetKeys(device: InputConfig.Device): boolean
	return request("ResetHotkeys", device)
end

-- Keyboard: the keys of two actions trade places.
local function swap(first: string, second: string)
	if currentKey(KEYBOARD_DEVICE, first) ~= currentKey(KEYBOARD_DEVICE, second) then
		request("SwapHotkeys", first, second, KEYBOARD_DEVICE)
	end
end

---------------------------------------------------------------------------------

return function(scope: Scope, context: any, menu: any): Instance
	local SettingsController = Knit.GetController("SettingsController")

	local page = scope:Value(GENERAL)

	-- The control layout is for players without a mouse: a touch screen, or a gamepad in use.
	local InputController = Knit.GetController("InputController")
	local function hasNoMouse(kind: string): boolean
		return UserInputService.TouchEnabled or kind ~= "KeyboardMouse"
	end
	local noMouse = scope:Value(hasNoMouse(InputController:GetDeviceKind()))
	local kindConnection = InputController.DeviceKindChanged:Connect(function(kind: string)
		noMouse:set(hasNoMouse(kind))
	end)
	table.insert(scope, function()
		kindConnection:Disconnect()
	end)

	local function setting(pageScope: Scope, name: string): Fusion.Value<any>
		return Bind.data(pageScope, `Settings.{name}`, SettingsConfig.Definitions[name].Default)
	end

	local function cycle(name: string, backwards: boolean?)
		local promise = SettingsController:Cycle(name, backwards)
		if promise then
			Kit.send(promise)
		end
	end

	-- An on / off setting.
	local function toggleRow(pageScope: Scope, order: number, name: string, label: string, hint: string?): Instance
		local value = setting(pageScope, name)
		return Kit.Row(pageScope, {
			Label = label,
			Hint = hint,
			HintBelow = hint ~= nil,
			LayoutOrder = order,
			Children = UI.Toggle(pageScope, {
				Value = pageScope:Computed(function(use): boolean
					return use(value) == true
				end),
				OnToggle = function()
					cycle(name)
				end,
			}),
		})
	end

	-- A setting with more than two values: the button shows the current one and steps on.
	local function cycleRow(
		pageScope: Scope,
		order: number,
		name: string,
		label: string,
		describe: (value: any) -> string,
		isOn: ((value: any) -> boolean)?,
		hint: string?
	): Instance
		local value = setting(pageScope, name)
		return Kit.Row(pageScope, {
			Label = label,
			Hint = hint,
			HintBelow = hint ~= nil,
			LayoutOrder = order,
			Children = UI.Button(pageScope, {
				Name = name,
				Variant = "Secondary",
				TextSize = Theme.TextSize.Small,
				Size = VALUE_BUTTON,
				Text = pageScope:Computed(function(use): string
					return describe(use(value))
				end),
				Selected = if isOn
					then pageScope:Computed(function(use): boolean
						return isOn(use(value))
					end)
					else nil,
				OnClick = function()
					cycle(name)
				end,
			}),
		})
	end

	-- "Default", "Auto" or "Custom", and the way into the editor of the custom one.
	local function controlLayoutRow(pageScope: Scope, order: number): Instance
		local value = setting(pageScope, LAYOUT_SETTING)
		local isCustom = pageScope:Computed(function(use): boolean
			return use(value) == CUSTOM_LAYOUT
		end)
		return Kit.Row(pageScope, {
			Label = "Button Layout",
			Hint = CONTROL_LAYOUT_HINT,
			HintBelow = true,
			LayoutOrder = order,
			Visible = noMouse,
			Children = {
				UI.Button(pageScope, {
					Name = "Customize",
					Text = "Customize",
					TextSize = Theme.TextSize.Small,
					Size = CUSTOMIZE_BUTTON,
					LayoutOrder = 1,
					Visible = isCustom,
					OnClick = function()
						-- The editor needs the screen: the tab makes room for it.
						context.Open(EDITOR_SCREEN)
						menu.Close()
					end,
				}),
				UI.Button(pageScope, {
					Name = LAYOUT_SETTING,
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					Size = VALUE_BUTTON,
					LayoutOrder = 2,
					-- Anything that is not a layout (a profile of another version) reads as the default.
					Text = pageScope:Computed(function(use): string
						local current = use(value)
						return if type(current) == "string" and (ControlsConfig.Layouts :: any)[current]
							then current
							else DEFAULT_LAYOUT
					end),
					Selected = pageScope:Computed(function(use): boolean
						local current = use(value)
						return current == CUSTOM_LAYOUT or current == ControlsConfig.Layouts.Auto
					end),
					OnClick = function()
						cycle(LAYOUT_SETTING)
					end,
				}),
			},
		})
	end

	---------------------------------------------------------------------------------

	local function generalPage(pageScope: Scope): Instance
		local volume = setting(pageScope, "Music")

		local reset = UI.Button(pageScope, {
			Name = "StatReset",
			Text = "Reset Stats",
			Variant = "Danger",
			TextSize = Theme.TextSize.Small,
			Size = VALUE_BUTTON,
			OnClick = function()
				context.Toggle(RESET_SCREEN)
			end,
		})
		Tooltip.attach(pageScope, reset, RESET_TIP)

		-- Two clicks: the first one only arms the button, for a few seconds.
		local resetArmed = pageScope:Value(false)
		local resetStamp = 0
		local resetSettings = UI.Button(pageScope, {
			Name = "SettingsReset",
			Variant = "Secondary",
			TextSize = Theme.TextSize.Small,
			Size = VALUE_BUTTON,
			Text = pageScope:Computed(function(use): string
				return if use(resetArmed) then RESET_SETTINGS_CONFIRM else RESET_SETTINGS
			end),
			Selected = resetArmed,
			OnClick = function()
				resetStamp += 1
				if peek(resetArmed) then
					resetArmed:set(false)
					Kit.send(SettingsController:Reset())
					return
				end
				local stamp = resetStamp
				resetArmed:set(true)
				task.delay(RESET_CONFIRM_SECONDS, function()
					if resetStamp == stamp then
						resetArmed:set(false)
					end
				end)
			end,
		})

		return UI.Scroll(pageScope, {
			Name = "Options",
			Children = {
				toggleRow(pageScope, 1, "Player_List", "Disable Player List"),
				toggleRow(pageScope, 2, "Join_Message", "Join Messages"),
				toggleRow(pageScope, 3, "Hide_Bounty", "Hide Bounty"),
				toggleRow(pageScope, 4, "Auto_Menu", "Auto Menu", AUTO_MENU_HINT),
				toggleRow(pageScope, 5, "Aim_Assist", "Aim Assist", AIM_ASSIST_HINT),
				-- Trading switched off (TradeConfig.Enabled): nobody can invite, nothing to refuse.
				(if TradeConfig.Enabled
					then toggleRow(pageScope, 6, "Trade_Requests", "Trade Requests", TRADE_HINT)
					else nil) :: any,
				toggleRow(pageScope, 7, "Charge_Toggle", "Tap to Charge", CHARGE_HINT),
				cycleRow(pageScope, 8, "UI_Style", "UI Style", function(value: any): string
					return if type(value) == "string" then value else "Rework"
				end, nil, UI_STYLE_HINT),
				cycleRow(pageScope, 9, "UI_Scale", "UI Scale", function(value: any): string
					return `{math.floor(UIConfig.ScaleFor(value) * 100 + 0.5)}%`
				end, function(value: any): boolean
					return value ~= 0
				end, UI_SCALE_HINT),
				cycleRow(pageScope, 10, "Camera_Lock", "Camera Lock", function(value: any): string
					return CAMERA_LOCK_LABELS[value] or "Off"
				end, function(value: any): boolean
					return value ~= 0
				end, CAMERA_LOCK_HINT),
				toggleRow(pageScope, 11, "Root_Lock", "Root Lock", ROOT_LOCK_HINT),
				controlLayoutRow(pageScope, 12),
				Kit.Row(pageScope, {
					Label = "Music",
					LayoutOrder = 13,
					-- The arrows wrap around (20 -> 0 and 0 -> 20).
					Children = Kit.Stepper(pageScope, {
						Text = pageScope:Computed(function(use): string
							return tostring(use(volume))
						end),
						OnStep = function(delta: number)
							cycle("Music", delta < 0)
						end,
					}),
				}),
				Kit.Row(pageScope, {
					Label = "Settings",
					Hint = RESET_SETTINGS_HINT,
					HintBelow = true,
					LayoutOrder = 14,
					Children = resetSettings,
				}),
				Kit.Row(pageScope, {
					Label = "Stats",
					Hint = STATS_HINT,
					HintBelow = true,
					LayoutOrder = 15,
					Children = reset,
				}),
			},
		})
	end

	local function optimizationPage(pageScope: Scope): Instance
		return UI.Scroll(pageScope, {
			Name = "Optimization",
			Children = {
				toggleRow(pageScope, 1, "Damage_Numbers", "Damage Numbers"),
				toggleRow(pageScope, 2, "Hit_Counter", "Damage Counter"),
				cycleRow(pageScope, 3, "Obs_Mode", "Observation Mode", function(value: any): string
					return if type(value) == "string" and value ~= "" then value else "Full"
				end),
				cycleRow(pageScope, 4, "Fast_Mode", "Fast Mode", function(value: any): string
					return if type(value) == "string" and value ~= "" then value else "Off"
				end, function(value: any): boolean
					return value == "On" or value == "Extreme"
				end),
			},
		})
	end

	---------------------------------------------------------------------------------
	-- Keybinds: what the two lists share.

	-- One request at a time: `busy` is true while the server is being asked.
	local function runner(pageScope: Scope): (Fusion.Value<boolean>, (callback: () -> ()) -> (), () -> boolean)
		local alive = true
		table.insert(pageScope, function()
			alive = false
		end)
		local busy = pageScope:Value(false)
		local function run(callback: () -> ())
			if peek(busy) then
				return
			end
			busy:set(true)
			task.spawn(function()
				pcall(callback)
				if alive then
					busy:set(false)
				end
			end)
		end
		return busy, run, function(): boolean
			return alive
		end
	end

	-- A line of help on the left, "Defaults" on the right, the list underneath.
	local function listPage(
		pageScope: Scope,
		name: string,
		help: UsedAs<string>,
		busy: UsedAs<boolean>,
		onDefaults: () -> (),
		rows: Fusion.Child
	): Instance
		return pageScope:New("Frame")({
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			[Fusion.Children] = {
				UI.Label(pageScope, {
					Name = "Hint",
					Text = help,
					Variant = "Small",
					Wrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, -(DEFAULTS_SIZE.X + Theme.Space.M), 0, BAR_HEIGHT),
				}),
				UI.Button(pageScope, {
					Name = "Defaults",
					Text = "Defaults",
					Variant = "Secondary",
					TextSize = Theme.TextSize.Small,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(DEFAULTS_SIZE.X, DEFAULTS_SIZE.Y),
					Disabled = busy,
					OnClick = onDefaults,
				}),
				UI.Scroll(pageScope, {
					Name = "List",
					Gap = 6,
					Position = UDim2.fromOffset(0, BAR_HEIGHT + Theme.Space.S),
					Size = UDim2.new(1, 0, 1, -(BAR_HEIGHT + Theme.Space.S)),
					Children = rows,
				}),
			},
		})
	end

	local function keyboardPage(pageScope: Scope): Instance
		local busy, run = runner(pageScope)
		local selected: Fusion.Value<string?> = pageScope:Value(nil :: string?)
		local hotkeys = Bind.data(pageScope, "Hotkeys", {})

		local rows: { Instance } = {}
		for order, entry in KEYBINDS_LIST do
			local action = entry.Action
			local keyText = pageScope:Computed(function(use): string
				return readKey(use(hotkeys), KEYBOARD_DEVICE, action)
			end)
			local isSelected = pageScope:Computed(function(use): boolean
				return use(selected) == action
			end)

			table.insert(
				rows,
				Kit.Row(pageScope, {
					Label = entry.Label,
					LayoutOrder = order,
					Height = 40,
					Selected = isSelected,
					Children = if entry.Rebind
						then UI.Button(pageScope, {
							Name = action,
							Text = keyText,
							Variant = "Secondary",
							TextSize = Theme.TextSize.Small,
							Size = UDim2.fromOffset(150, 30),
							Selected = isSelected,
							Disabled = busy,
							OnClick = function()
								local first = peek(selected)
								if not first then
									selected:set(action)
									return
								end

								selected:set(nil)
								if first ~= action then
									run(function()
										swap(first, action)
									end)
								end
							end,
						})
						else Kit.KeyCap(pageScope, keyText),
				})
			)
		end

		return listPage(
			pageScope,
			"Keyboard",
			pageScope:Computed(function(use): string
				if use(busy) then
					return SAVING
				end
				return if use(selected) then KEYBOARD_SELECTED_HINT else KEYBOARD_HINT
			end),
			busy,
			function()
				selected:set(nil)
				run(function()
					resetKeys(KEYBOARD_DEVICE)
				end)
			end,
			rows
		)
	end

	local function layoutRow(pageScope: Scope, order: number): Instance
		return cycleRow(pageScope, order, "ControllerType", "Controller Layout", function(value: any): string
			return LAYOUT_LABELS[value] or LAYOUT_LABELS.Legacy
		end, function(value: any): boolean
			return value == "Shortcut"
		end)
	end

	-- The layout switch, then every gamepad action of the layout in use with its button.
	local function controllerPage(pageScope: Scope): Instance
		local busy, run, isAlive = runner(pageScope)
		local layout = setting(pageScope, "ControllerType")
		local hotkeys = Bind.data(pageScope, "Hotkeys", {})
		-- The action waiting for a button, and what the last change came to.
		local capturing: Fusion.Value<string?> = pageScope:Value(nil :: string?)
		local status = pageScope:Value("")
		local cancelCapture: (() -> ())? = nil

		local function stopCapture()
			local cancel = cancelCapture
			cancelCapture = nil
			capturing:set(nil)
			if cancel then
				cancel()
			end
		end
		-- Leaving the page, or the list, gives the gamepad back.
		table.insert(pageScope, function()
			local cancel = cancelCapture
			cancelCapture = nil
			if cancel then
				cancel()
			end
		end)

		local function capture(entry: InputConfig.PadEntry, device: InputConfig.Device)
			if peek(busy) then
				return
			end
			local action = entry.Action
			local same = peek(capturing) == action
			stopCapture()
			-- "Change" on the row that is waiting gives up.
			if same then
				return
			end

			status:set("")
			capturing:set(action)
			local cancel: (() -> ())? = nil
			cancel = InputController:CapturePadButton(function(keyName: string?)
				if not isAlive() or cancelCapture ~= cancel then
					return
				end
				cancelCapture = nil
				capturing:set(nil)
				if not keyName then
					status:set(PAD_CANCELLED)
				elseif not InputConfig.CanBind(device, action, keyName) then
					status:set(PAD_REFUSED)
				else
					run(function()
						local accepted = setKey(action, device, keyName)
						if isAlive() then
							status:set(if accepted then "" else PAD_REFUSED)
						end
					end)
				end
			end)
			cancelCapture = cancel
		end

		local list = pageScope:Computed(function(use, listScope: Scope): { Instance }
			local device = InputConfig.PadDevice(use(layout))
			local entries = InputConfig.PadActions[device]

			local rows: { Instance } = {}
			for order, entry in entries do
				local action = entry.Action
				local key = listScope:Computed(function(inner): string
					return readKey(inner(hotkeys), device, action)
				end)
				-- Another action that can be asked for at the same moment on the same button.
				local shared = listScope:Computed(function(inner): boolean
					local all = inner(hotkeys)
					local mine = readKey(all, device, action)
					if mine == InputConfig.Unbound then
						return false
					end
					for _, other in entries do
						if
							InputConfig.Conflicts(device, action, other.Action)
							and readKey(all, device, other.Action) == mine
						then
							return true
						end
					end
					return false
				end)
				local isWaiting = listScope:Computed(function(inner): boolean
					return inner(capturing) == action
				end)

				-- An ability of the Advanced layout is a chord: its fruit's menu button, then its own.
				local buttons: { UsedAs<string> } = {}
				if entry.Fruit and not entry.Menu then
					local menuAction = `Menu{entry.Fruit}`
					table.insert(
						buttons,
						listScope:Computed(function(inner): string
							return readKey(inner(hotkeys), device, menuAction)
						end)
					)
				end
				table.insert(buttons, key)

				table.insert(
					rows,
					Kit.Row(listScope, {
						Label = entry.Label,
						Hint = listScope:Computed(function(inner): string
							return if inner(shared) then PAD_SHARED else ""
						end),
						HintColor = Theme.Colors.Danger,
						HintBelow = false,
						LayoutOrder = order + 1,
						Height = 40,
						Selected = isWaiting,
						Children = {
							Kit.PadCombo(listScope, buttons, 1),
							UI.Button(listScope, {
								Name = action,
								Variant = "Secondary",
								TextSize = Theme.TextSize.Small,
								Size = CHANGE_BUTTON,
								LayoutOrder = 2,
								Selected = isWaiting,
								Disabled = busy,
								Text = listScope:Computed(function(inner): string
									return if inner(isWaiting) then "Press..." else "Change"
								end),
								OnClick = function()
									capture(entry, device)
								end,
							}),
						},
					})
				)
			end
			return rows
		end)
		-- Another layout is another list: a capture begun on the old one means nothing there.
		pageScope:Observer(layout):onChange(stopCapture)

		return listPage(
			pageScope,
			"Controller",
			pageScope:Computed(function(use): string
				local waiting = use(capturing)
				if waiting then
					return "Press the new button now. View / Select cancels."
				elseif use(busy) then
					return SAVING
				end
				local last = use(status)
				return if last ~= "" then last else PAD_HINT
			end),
			busy,
			function()
				stopCapture()
				status:set("")
				local device = InputConfig.PadDevice(peek(layout))
				run(function()
					resetKeys(device)
				end)
			end,
			{ layoutRow(pageScope, 1), list } :: { any }
		)
	end

	-- The device switch, then the list of that device. It opens on the device in use and
	-- stays where the player puts it: following the last input would pull the list away
	-- from someone who reaches for the mouse while rebinding the pad.
	local function keybindsPage(pageScope: Scope): Instance
		local device = pageScope:Value(if InputController:IsUsingGamepad() then CONTROLLER else KEYBOARD)
		local top = DEVICE_TABS_HEIGHT + Theme.Space.S
		return pageScope:New("Frame")({
			Name = "Keybinds",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			[Fusion.Children] = {
				UI.Tabs(pageScope, {
					Name = "Device",
					Tabs = {
						{ Key = KEYBOARD, Text = "Keyboard" },
						{ Key = CONTROLLER, Text = "Controller" },
					},
					Selected = device,
					TabSize = UDim2.fromOffset(150, DEVICE_TABS_HEIGHT),
				}),
				pageScope:New("Frame")({
					Name = "Device",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, top),
					Size = UDim2.new(1, 0, 1, -top),
					[Fusion.Children] = pageScope:Computed(function(use, deviceScope: Scope): Instance
						return if use(device) == CONTROLLER then controllerPage(deviceScope) else keyboardPage(deviceScope)
					end),
				}),
			},
		})
	end

	---------------------------------------------------------------------------------

	local content = scope:Computed(function(use, pageScope: Scope): Instance
		local current = use(page)
		if current == GENERAL then
			return generalPage(pageScope)
		elseif current == OPTIMIZATION then
			return optimizationPage(pageScope)
		end
		return keybindsPage(pageScope)
	end)

	return UI.Window(scope, {
		Name = "Settings",
		Title = "Settings",
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		AnchorPoint = Kit.WindowAnchor,
		Position = Kit.WindowPosition,
		OnClose = menu.Close,
		Children = {
			UI.Tabs(scope, {
				Tabs = {
					{ Key = GENERAL, Text = "General" },
					{ Key = OPTIMIZATION, Text = "Optimization" },
					{ Key = KEYBINDS, Text = "Keybinds" },
				},
				Selected = page,
				TabSize = UDim2.fromOffset(160, TABS_HEIGHT),
			}),
			scope:New("Frame")({
				Name = "Page",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, TABS_HEIGHT + Theme.Space.M),
				Size = UDim2.new(1, 0, 1, -(TABS_HEIGHT + Theme.Space.M)),
				[Fusion.Children] = content,
			}),
		},
	})
end
