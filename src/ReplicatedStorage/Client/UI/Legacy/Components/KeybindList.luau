--!strict
--[[
	The two keybind lists of the legacy settings tab, built with the Kit: a scrolling list
	of uniform rows, the name of the action on the left and its key in a white box on the
	right.

		local list = KeybindList.keyboard(scope, active, { Size = UDim2.fromScale(1, 1), Visible = shown })
		local list = KeybindList.controller(scope, active, { ... })

		list.Root    -- the Kit.Scroll, to parent
		list.Help    -- state: the line of help to show beside the list
		list.Reset   -- "Defaults": restores this list and nothing else

	`active` is state: whether that list is the one in view. A list that is left drops what
	it was in the middle of (a selected key, a capture).

	The two devices are separate layouts and nothing done to one touches the other; each
	is saved in the player's profile (HotkeyService). Every change is a request to that
	service, which decides (InputConfig); this module never writes anything itself, and the
	lists show what is saved (the replicated Hotkeys table, read through InputConfig.ReadKey
	as the server reads it), not what was clicked.

	Keyboard. As in the old menu, keys are not typed: clicking a first key selects it (its
	row turns blue), clicking a second one swaps the keys of the two actions. The last
	three rows are not actions: the old game listed them as "Unassigned" (Tab, P, U) and
	nothing ever read them. They are kept, named for what they are good for - spare keys
	to swap into an action - because swapping is the only way this list has to give an
	action a key no other action holds.

	Controller. The old list was a picture: fixed texts such as "L2+A", nothing behind
	them. The first row is the layout switch (Classic / Advanced, each with its own
	bindings), then one row per action a gamepad can trigger in the layout in use, with the
	player's own buttons. Clicking the box of a row waits for the next press of a gamepad
	button (InputController:CapturePadButton: that press goes nowhere else) and asks the
	server to bind it; View / Select or a few seconds without a press cancel. A button
	another action of the same context holds trades places with it (the server decides),
	and a button the engine keeps is refused. Two actions that do share a button (a profile
	older than these rules) are both marked.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local SettingsConfig = require(ReplicatedStorage.Shared.Configs.SettingsConfig)

type Scope = Fusion.Scope<typeof(Fusion)>

export type List = {
	Root: ScrollingFrame,
	Help: Fusion.StateObject<string>,
	Reset: () -> (),
}

local peek = Fusion.peek

local KEYBOARD_DEVICE: InputConfig.Device = "KB"

-- The keyboard list, in the order the old menu drew it.
local KEYBOARD_ROWS: { { Action: string, Label: string } } = {
	{ Action = "DF1A", Label = "Devil Fruit Ability 1" },
	{ Action = "DF1B", Label = "Devil Fruit Ability 2" },
	{ Action = "DF1C", Label = "Devil Fruit Ability 3" },
	{ Action = "DF1D", Label = "Devil Fruit Ability 4" },
	{ Action = "DF1E", Label = "Devil Fruit Ability 5" },
	{ Action = "DF1F", Label = "Devil Fruit Ability 6" },
	{ Action = "DF2A", Label = "Devil Fruit Ability 7" },
	{ Action = "DF2B", Label = "Devil Fruit Ability 8" },
	{ Action = "DF2C", Label = "Devil Fruit Ability 9" },
	{ Action = "DF2D", Label = "Devil Fruit Ability 10" },
	{ Action = "DF2E", Label = "Devil Fruit Ability 11" },
	{ Action = "DF2F", Label = "Devil Fruit Ability 12" },
	{ Action = "Dash", Label = "Dash" },
	{ Action = "Haki", Label = "Haki" },
	{ Action = "Shave", Label = "Shave" },
	{ Action = "Observation", Label = "Observation" },
	{ Action = "Emotes", Label = "Emotes Menu" },
	{ Action = "Conq", Label = "Conqueror's Haki" },
	{ Action = "SpFn", Label = "Special Attack" },
	-- Not actions (InputConfig: "never had code behind them"): keys held in reserve.
	{ Action = "Unassigned1", Label = "Spare Key 1 (no action)" },
	{ Action = "Unassigned2", Label = "Spare Key 2 (no action)" },
	{ Action = "Unassigned3", Label = "Spare Key 3 (no action)" },
}
-- An action whose system is switched off (InputConfig.IsEnabled) has no row.
for index = #KEYBOARD_ROWS, 1, -1 do
	if not InputConfig.IsEnabled(KEYBOARD_ROWS[index].Action) then
		table.remove(KEYBOARD_ROWS, index)
	end
end

-- Design pixels.
local ROW_HEIGHT = 32
local ROW_GAP = 4
local KEY_WIDTH = 150
local KEY_INSET = 2

local SELECTED_COLOR = Color3.new(0.5, 0.5, 1)
local IDLE_COLOR = Color3.new(1, 1, 1)
local SELECTED_TRANSPARENCY = 0.35
local IDLE_TRANSPARENCY = 0.85

local KEYBOARD_HINT = "Click a key, then another one: the two actions swap keys."
local KEYBOARD_SELECTED_HINT = "Now click the key to swap it with."
local PAD_HINT = "Click the button of an action, then press the new button. A button in use trades places."
local PAD_WAITING = "Press the new button now. View / Select cancels."
local SAVING = "Saving..."
local PAD_CANCELLED = "Nothing changed."
local PAD_REFUSED = "That button cannot go there: it is needed where it is."
local PAD_SHARED = "shares its button"
local PAD_PRESS = "Press..."

-- Settings.ControllerType as the menu calls it.
local LAYOUT_SETTING = "ControllerType"
local LAYOUT_ROW_TEXT = "Controller Layout"
local LAYOUT_LABELS: { [string]: string } = { Legacy = "Classic", Shortcut = "Advanced" }

-- What an action without a button shows.
local NO_BUTTON = "-"

---------------------------------------------------------------------------------
-- Requests

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

-- One request at a time: `busy` is true while the server is being asked.
local function runner(scope: Scope): (Fusion.Value<boolean>, (callback: () -> ()) -> (), () -> boolean)
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	local busy = scope:Value(false)
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

-- "ButtonL2" -> "L2", "DPadUp" -> "DPad Up": the way the old list wrote buttons.
local function padText(key: string): string
	if key == "" or key == InputConfig.Unbound then
		return NO_BUTTON
	end
	local text = string.gsub(key, "^Button", "")
	text = string.gsub(text, "^DPad(%a)", "DPad %1")
	return text
end

---------------------------------------------------------------------------------
-- Rows

type RowProps = {
	Name: string,
	LayoutOrder: number,
	Text: Fusion.UsedAs<string>,
	TextColor: Fusion.UsedAs<Color3>?,
	-- The row in the middle of something (a key picked for a swap, a capture): blue.
	Highlighted: Fusion.StateObject<boolean>,
	KeyText: Fusion.UsedAs<string>,
	OnClick: () -> (),
}

-- One line of a list: the action on the left, its key in a box on the right.
local function buildRow(scope: Scope, props: RowProps): Instance
	return scope:New("Frame")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BorderSizePixel = 0,
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(props.Highlighted) then SELECTED_COLOR else IDLE_COLOR
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(props.Highlighted) then SELECTED_TRANSPARENCY else IDLE_TRANSPARENCY
		end),
		[Fusion.Children] = {
			Kit.Label(scope, {
				Name = "Action",
				Text = props.Text,
				Color = props.TextColor,
				TextSize = Kit.TextSize.Small,
				Fit = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(Kit.Space.S, 0),
				Size = UDim2.new(1, -(KEY_WIDTH + KEY_INSET + Kit.Space.S * 2), 1, 0),
			}),
			Kit.Button(scope, {
				Name = "Key",
				Variant = "Box",
				Text = props.KeyText,
				TextSize = Kit.TextSize.Small,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -KEY_INSET, 0.5, 0),
				Size = UDim2.fromOffset(KEY_WIDTH, ROW_HEIGHT - KEY_INSET * 2),
				OnClick = props.OnClick,
			}),
		},
	})
end

local function buildList(scope: Scope, name: string, layout: Kit.Layout, rows: any): ScrollingFrame
	local props: any = table.clone(layout)
	props.Name = name
	props.Gap = ROW_GAP
	props.Children = rows
	return Kit.Scroll(scope, props)
end

local KeybindList = {}

---------------------------------------------------------------------------------
-- Keyboard

function KeybindList.keyboard(scope: Scope, active: Fusion.StateObject<boolean>, layout: Kit.Layout): List
	local busy, run = runner(scope)
	local selected: Fusion.Value<string?> = scope:Value(nil :: string?)
	local hotkeys = Bind.data(scope, "Hotkeys", {})

	local rows: { Instance } = {}
	for order, entry in KEYBOARD_ROWS do
		local action = entry.Action
		table.insert(
			rows,
			buildRow(scope, {
				Name = action,
				LayoutOrder = order,
				Text = entry.Label,
				Highlighted = scope:Computed(function(use): boolean
					return use(selected) == action
				end),
				KeyText = scope:Computed(function(use): string
					return readKey(use(hotkeys), KEYBOARD_DEVICE, action)
				end),
				OnClick = function()
					if peek(busy) then
						return
					end
					local first = peek(selected)
					if not first then
						selected:set(action)
						return
					end

					selected:set(nil)
					if first ~= action then
						run(function()
							-- The keys of the two actions trade places.
							if currentKey(KEYBOARD_DEVICE, first) ~= currentKey(KEYBOARD_DEVICE, action) then
								request("SwapHotkeys", first, action, KEYBOARD_DEVICE)
							end
						end)
					end
				end,
			})
		)
	end

	-- A key picked and then left there must not swap with a click made much later.
	scope:Observer(active):onChange(function()
		if not peek(active) then
			selected:set(nil)
		end
	end)

	return {
		Root = buildList(scope, "Keyboard", layout, rows),
		Help = scope:Computed(function(use): string
			if use(busy) then
				return SAVING
			end
			return if use(selected) then KEYBOARD_SELECTED_HINT else KEYBOARD_HINT
		end),
		Reset = function()
			selected:set(nil)
			run(function()
				request("ResetHotkeys", KEYBOARD_DEVICE)
			end)
		end,
	}
end

---------------------------------------------------------------------------------
-- Controller

function KeybindList.controller(scope: Scope, active: Fusion.StateObject<boolean>, layout: Kit.Layout): List
	local InputController = Knit.GetController("InputController")
	local SettingsController = Knit.GetController("SettingsController")

	local busy, run, isAlive = runner(scope)
	local padLayout = Bind.data(scope, `Settings.{LAYOUT_SETTING}`, SettingsConfig.Definitions[LAYOUT_SETTING].Default)
	local hotkeys = Bind.data(scope, "Hotkeys", {})
	-- The action waiting for a button, and what the last change came to.
	local capturing: Fusion.Value<string?> = scope:Value(nil :: string?)
	local status = scope:Value("")
	local cancelCapture: (() -> ())? = nil

	local function stopCapture()
		local cancel = cancelCapture
		cancelCapture = nil
		capturing:set(nil)
		if cancel then
			cancel()
		end
	end
	-- Leaving the menu gives the gamepad back.
	table.insert(scope, function()
		local cancel = cancelCapture
		cancelCapture = nil
		if cancel then
			cancel()
		end
	end)

	local function capture(action: string, device: InputConfig.Device)
		if peek(busy) then
			return
		end
		local same = peek(capturing) == action
		stopCapture()
		-- The button of the row that is waiting gives up.
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
					local accepted = request("SetHotkey", action, device, keyName)
					if isAlive() then
						status:set(if accepted then "" else PAD_REFUSED)
					end
				end)
			end
		end)
		cancelCapture = cancel
	end

	-- The layout switch: the first row, whatever the layout.
	local layoutRow = buildRow(scope, {
		Name = "Layout",
		LayoutOrder = 0,
		Text = LAYOUT_ROW_TEXT,
		Highlighted = scope:Value(false),
		KeyText = scope:Computed(function(use): string
			return LAYOUT_LABELS[use(padLayout)] or LAYOUT_LABELS.Legacy
		end),
		OnClick = function()
			local promise = SettingsController:Cycle(LAYOUT_SETTING)
			if promise then
				promise:catch(warn)
			end
		end,
	})

	-- Every gamepad action of the layout in use with its button: rebuilt when the layout
	-- changes (the rows live in the scope of this computation).
	local actionRows = scope:Computed(function(use, rowsScope: Scope): { Instance }
		local device = InputConfig.PadDevice(use(padLayout))
		local entries = InputConfig.PadActions[device]

		local rows: { Instance } = {}
		for order, entry in entries do
			local action = entry.Action

			-- Another action that can be asked for at the same moment on the same button.
			local shared = rowsScope:Computed(function(inner): boolean
				local all = inner(hotkeys)
				local mine = readKey(all, device, action)
				if mine == InputConfig.Unbound then
					return false
				end
				for _, other in entries do
					if InputConfig.Conflicts(device, action, other.Action) and readKey(all, device, other.Action) == mine then
						return true
					end
				end
				return false
			end)
			local isWaiting = rowsScope:Computed(function(inner): boolean
				return inner(capturing) == action
			end)
			-- An ability of the Advanced layout is a chord: its fruit's menu button, then its own.
			local menuAction = if entry.Fruit and not entry.Menu then `Menu{entry.Fruit}` else nil

			table.insert(
				rows,
				buildRow(rowsScope, {
					Name = `Pad_{action}`,
					LayoutOrder = order,
					Text = rowsScope:Computed(function(inner): string
						return if inner(shared) then `{entry.Label} ({PAD_SHARED})` else entry.Label
					end),
					TextColor = rowsScope:Computed(function(inner): Color3
						return if inner(shared) then Kit.Colors.Bad else Kit.Colors.Text
					end),
					Highlighted = isWaiting,
					KeyText = rowsScope:Computed(function(inner): string
						if inner(isWaiting) then
							return PAD_PRESS
						end
						local all = inner(hotkeys)
						local own = padText(readKey(all, device, action))
						return if menuAction then `{padText(readKey(all, device, menuAction))}+{own}` else own
					end),
					OnClick = function()
						capture(action, device)
					end,
				})
			)
		end
		return rows
	end)

	-- Another layout is another list: a capture begun on the old one means nothing there.
	scope:Observer(padLayout):onChange(stopCapture)
	-- So does one begun on a list that is no longer in view.
	scope:Observer(active):onChange(function()
		if not peek(active) then
			stopCapture()
			status:set("")
		end
	end)

	return {
		Root = buildList(scope, "Controller", layout, { layoutRow, actionRows } :: { any }),
		Help = scope:Computed(function(use): string
			if use(capturing) then
				return PAD_WAITING
			elseif use(busy) then
				return SAVING
			end
			local last = use(status)
			return if last ~= "" then last else PAD_HINT
		end),
		Reset = function()
			stopCapture()
			status:set("")
			local device = InputConfig.PadDevice(peek(padLayout))
			run(function()
				request("ResetHotkeys", device)
			end)
		end,
	}
end

return KeybindList
