--!strict
--[[
	Everything about hotkeys that is not the player's own choice: which actions exist,
	on which device each can be bound, which key names are accepted, what the defaults
	are, and which two actions may not share a key.

	The bindings themselves are player data, one row per action with one column per
	device layout:

		Hotkeys.<Action> = { KB = name, GP = name, GC = name }

	names being Enum.KeyCode names or "None". The three columns are independent: nothing
	that changes one ever touches another.
		KB   keyboard
		GP   gamepad, Advanced layout (Settings.ControllerType = "Shortcut")
		GC   gamepad, Classic layout  (Settings.ControllerType = "Legacy")
	The two gamepad layouts do not have the same actions (Classic selects an ability with
	two buttons and uses it with a third; Advanced has a chord per ability) nor the same
	defaults, so each has its own column instead of sharing one that could only suit one
	of them. GP is the column the Advanced layout always read, so what older profiles hold
	there keeps its meaning; GC is new and starts from the buttons the Classic layout used
	to have hardcoded.

	Contexts. Two actions may not share a key when they can be asked for at the same
	moment, that is when they share a context:
		KB: one context, "Main" (every action).
		GC: one context, "Base" (every action).
		GP: "Base" (no fruit menu held: the basic actions), "Fruit1" and "Fruit2" (the six
		    abilities of a fruit, while its menu button is held). Both fruits use the same
		    buttons on purpose, and share them with the basic actions: the held menu decides
		    who gets the press. The two menu buttons belong to all three contexts - a menu
		    button is a menu button whatever else is held.
	Reserved: a button the engine needs in a context cannot be bound there (ButtonA jumps,
	so no "Base" action may take it; inside a fruit menu it is free). ButtonSelect opens the
	interface (NavigationController) and Start is the Roblox menu: neither is a key name.

	Shared: the client maps input with it (InputController, the settings tab, the mobile
	and controller screens) and the server validates rebinding against it (HotkeyService).
]]
local ConquerorConfig = require(script.Parent.ConquerorConfig)

export type Device = "KB" | "GP" | "GC"

export type MobileButton = {
	-- Action fired, or nil for a button that only shows.
	Action: string?,
	Skill: "Melee" | "Sword" | "Haki",
	Level: number,
	-- Data path of a number that must also be above 0 for the button to show.
	Unlock: string?,
	-- "Tap": the button arms the action and the next tap on the world fires it there.
	-- "Toggle": the button fires at once and is tinted while the status is on the character.
	Mode: "Tap" | "Toggle" | "None",
	ActiveColor: Color3?,
	-- Character attribute that means "on", for Toggle buttons.
	Status: string?,
}

export type PadEntry = {
	Action: string,
	-- What the settings tab calls it.
	Label: string,
	Default: string,
	-- GP only: the fruit whose menu the action lives in, or opens (nil: a basic action).
	Fruit: number?,
	-- GP only: the button that opens the menu of fruit `Fruit`. Part of every context.
	Menu: boolean?,
}

local SLOT_LETTERS = { "A", "B", "C", "D", "E", "F" }
local BASE = "Base"
local MAIN = "Main"

local InputConfig = {}

--[[
	Actions of a system that is switched off. They keep their rows, defaults and contexts
	(a profile keeps its shape and its keys, and HotkeyService still knows the names), but
	nothing offers them: InputController binds no key to them, and the lists below that
	the interface draws from (PadActions, MobileButtons) leave them out. A screen with a
	list of its own asks IsEnabled.
]]
local DISABLED_ACTIONS: { [string]: boolean } = {
	Conq = not ConquerorConfig.Enabled,
}

-- Whether the action can be used at all right now (false: its system is switched off).
function InputConfig.IsEnabled(action: string): boolean
	return DISABLED_ACTIONS[action] ~= true
end

InputConfig.Unbound = "None"
InputConfig.SlotLetters = table.freeze(SLOT_LETTERS)

-- Hotkey name of an ability: fruit slot 1-2, ability slot 1-6 -> "DF1A".."DF2F".
function InputConfig.GetAbilityAction(fruitSlot: number, abilitySlot: number): string
	return `DF{fruitSlot}{SLOT_LETTERS[abilitySlot]}`
end

-- The legacy gamepad index 1-12 (D-pad selection) -> fruit slot, ability slot.
function InputConfig.SplitAbilityIndex(index: number): (number, number)
	return (index - 1) // 6 + 1, (index - 1) % 6 + 1
end

local abilityActions: { string } = {}
for fruitSlot = 1, 2 do
	for abilitySlot = 1, 6 do
		table.insert(abilityActions, InputConfig.GetAbilityAction(fruitSlot, abilitySlot))
	end
end
InputConfig.AbilityActions = table.freeze(abilityActions)

-- Settings.ControllerType values.
InputConfig.ControllerTypes = table.freeze({ Legacy = "Legacy", Shortcut = "Shortcut" })

-- Actions InputController handles itself: the Classic layout's selection, and its
-- "use the selected ability" button (the legacy name of that row is kept).
InputConfig.SelectNext = "SelectNext"
InputConfig.SelectPrevious = "SelectPrevious"
InputConfig.UseSelected = "DPadFn"

--[[
	"Conq" (Conqueror's Haki, keyboard T) was saved by the legacy game without any script
	reading it; it is an action like the others now (ConquerorService). "Unassigned1-3"
	never had code behind them: they are kept so that their keys stay taken.
]]
local keyboardList: { { Action: string, Default: string } } = {
	{ Action = "Dash", Default = "E" },
	{ Action = "Shave", Default = "LeftControl" },
	{ Action = "Haki", Default = "Q" },
	{ Action = "Observation", Default = "R" },
	{ Action = "Conq", Default = "T" },
	{ Action = "Emotes", Default = "LeftAlt" },
	{ Action = "SpFn", Default = "Y" },
	{ Action = "Unassigned1", Default = "Tab" },
	{ Action = "Unassigned2", Default = "P" },
	{ Action = "Unassigned3", Default = "U" },
}
local ABILITY_KEYS = { "Z", "X", "C", "V", "B", "N", "F", "G", "H", "J", "K", "L" }
for index, action in abilityActions do
	table.insert(keyboardList, { Action = action, Default = ABILITY_KEYS[index] })
end

-- The buttons of an ability inside its fruit's menu (Advanced layout), by ability slot.
local CHORD_BUTTONS = { "ButtonA", "ButtonX", "ButtonB", "ButtonY", "ButtonR1", "ButtonR2" }

--[[
	What a gamepad can trigger, per layout, in the order the settings tab lists it, with
	the default button of each. "Attack" is the basic swing of the held weapon,
	"CameraLock" the camera lock (CameraLockController), "ToolNext" / "ToolPrevious" walk
	through the tools of the backpack (ToolCycleController).

	Advanced: L1 is a fruit menu and R1 the special attack, so the engine's own L1 / R1
	walk through the hotbar has no button left; the tools are on the D-pad, which this
	layout leaves free. Classic: the D-pad selects abilities, and the tools keep the two
	buttons the engine used for them.
]]
local advancedList: { PadEntry } = {
	{ Action = "Menu1", Label = "Fruit 1 abilities (hold)", Default = "ButtonL2", Fruit = 1, Menu = true },
	{ Action = "Menu2", Label = "Fruit 2 abilities (hold)", Default = "ButtonL1", Fruit = 2, Menu = true },
}
for fruitSlot = 1, 2 do
	for abilitySlot = 1, #SLOT_LETTERS do
		table.insert(advancedList, {
			Action = InputConfig.GetAbilityAction(fruitSlot, abilitySlot),
			Label = `Devil Fruit Ability {(fruitSlot - 1) * #SLOT_LETTERS + abilitySlot}`,
			Default = CHORD_BUTTONS[abilitySlot],
			Fruit = fruitSlot,
		})
	end
end
local advancedBasics: { PadEntry } = {
	{ Action = "Attack", Label = "Attack", Default = "ButtonR2" },
	{ Action = "SpFn", Label = "Special Attack", Default = "ButtonR1" },
	{ Action = "CameraLock", Label = "Camera Lock", Default = "ButtonR3" },
	{ Action = "Dash", Label = "Dash", Default = "ButtonB" },
	{ Action = "Shave", Label = "Shave", Default = "ButtonL3" },
	{ Action = "Haki", Label = "Haki", Default = "ButtonX" },
	{ Action = "Observation", Label = "Observation", Default = "ButtonY" },
	{ Action = "Conq", Label = "Conqueror's Haki", Default = "DPadRight" },
	{ Action = "ToolNext", Label = "Next tool", Default = "DPadUp" },
	{ Action = "ToolPrevious", Label = "Previous tool", Default = "DPadDown" },
}
for _, entry in advancedBasics do
	table.insert(advancedList, entry)
end

local classicList: { PadEntry } = {
	{ Action = "SelectNext", Label = "Next ability", Default = "DPadUp" },
	{ Action = "SelectPrevious", Label = "Previous ability", Default = "DPadDown" },
	{ Action = "DPadFn", Label = "Use the selected ability", Default = "ButtonL2" },
	{ Action = "Attack", Label = "Attack", Default = "ButtonR2" },
	{ Action = "SpFn", Label = "Special Attack", Default = "DPadLeft" },
	{ Action = "CameraLock", Label = "Camera Lock", Default = "ButtonR3" },
	{ Action = "Dash", Label = "Dash", Default = "ButtonX" },
	{ Action = "Shave", Label = "Shave", Default = "ButtonL3" },
	{ Action = "Haki", Label = "Haki", Default = "ButtonB" },
	{ Action = "Observation", Label = "Observation", Default = "ButtonY" },
	{ Action = "Conq", Label = "Conqueror's Haki", Default = "DPadRight" },
	{ Action = "ToolNext", Label = "Next tool", Default = "ButtonR1" },
	{ Action = "ToolPrevious", Label = "Previous tool", Default = "ButtonL1" },
}

for _, list in { advancedList, classicList } do
	for _, entry in list do
		table.freeze(entry)
	end
end

local function enabledEntries(list: { PadEntry }): { PadEntry }
	local kept: { PadEntry } = {}
	for _, entry in list do
		if InputConfig.IsEnabled(entry.Action) then
			table.insert(kept, entry)
		end
	end
	return table.freeze(kept)
end

-- The gamepad actions per layout column ("GP" / "GC"), in listing order. Only the ones
-- that can be used: what binds and what lists both read this.
InputConfig.PadActions = table.freeze({
	GP = enabledEntries(advancedList),
	GC = enabledEntries(classicList),
}) :: { [string]: { PadEntry } }

-- { [device]: { [action]: { [context]: true } } }: the actions of a device and where each lives.
local contexts: { [string]: { [string]: { [string]: boolean } } } = { KB = {}, GP = {}, GC = {} }
-- { [action]: { KB, GP, GC } }: what a new profile starts with and what "Defaults" restores.
local defaults: { [string]: { [string]: string } } = {}

local function setDefault(action: string, device: string, key: string)
	local row = defaults[action]
	if not row then
		row = { KB = InputConfig.Unbound, GP = InputConfig.Unbound, GC = InputConfig.Unbound }
		defaults[action] = row
	end
	row[device] = key
end

for _, entry in keyboardList do
	contexts.KB[entry.Action] = table.freeze({ [MAIN] = true })
	setDefault(entry.Action, "KB", entry.Default)
end
for _, entry in advancedList do
	local where: { [string]: boolean }
	if entry.Menu then
		where = { [BASE] = true, Fruit1 = true, Fruit2 = true }
	elseif entry.Fruit then
		where = { [`Fruit{entry.Fruit}`] = true }
	else
		where = { [BASE] = true }
	end
	contexts.GP[entry.Action] = table.freeze(where)
	setDefault(entry.Action, "GP", entry.Default)
end
for _, entry in classicList do
	contexts.GC[entry.Action] = table.freeze({ [BASE] = true })
	setDefault(entry.Action, "GC", entry.Default)
end
-- Rows the legacy profiles carry that nothing reads any more (the two mode buttons the
-- Advanced layout does without): kept in the template so old profiles keep their shape.
setDefault("Mode1", "GP", InputConfig.Unbound)
setDefault("Mode2", "GP", InputConfig.Unbound)

for _, row in defaults do
	table.freeze(row)
end
for _, set in contexts do
	table.freeze(set)
end

InputConfig.Contexts = table.freeze(contexts) :: { [Device]: { [string]: { [string]: boolean } } }
InputConfig.Defaults = table.freeze(defaults) :: { [string]: { [string]: string } }

local function toSet(names: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, name in names do
		set[name] = true
	end
	return table.freeze(set)
end

local PAD_KEYS = toSet({
	"ButtonA", "ButtonB", "ButtonX", "ButtonY",
	"ButtonL1", "ButtonL2", "ButtonL3", "ButtonR1", "ButtonR2", "ButtonR3",
	"DPadUp", "DPadDown", "DPadLeft", "DPadRight",
})

-- Accepted key names per device ("None" is always accepted and means unbound).
-- W A S D, Space, Escape, Slash and the mouse are left out: they belong to the engine.
-- So do Start (the Roblox menu) and Select (the interface) on a gamepad.
InputConfig.Keys = table.freeze({
	KB = toSet({
		"B", "C", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "T", "U", "V", "X", "Y", "Z",
		"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero",
		"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10",
		"LeftControl", "RightControl", "LeftAlt", "RightAlt", "LeftShift", "RightShift",
		"Tab", "CapsLock", "Backquote", "Minus", "Equals", "LeftBracket", "RightBracket",
		"Semicolon", "Quote", "Comma", "Period", "BackSlash",
	}),
	GP = PAD_KEYS,
	GC = PAD_KEYS,
}) :: { [Device]: { [string]: boolean } }

-- { [device]: { [context]: { [key]: true } } }: keys the engine keeps in a context.
InputConfig.Reserved = table.freeze({
	KB = table.freeze({}),
	GP = table.freeze({ [BASE] = toSet({ "ButtonA" }) }),
	GC = table.freeze({ [BASE] = toSet({ "ButtonA" }) }),
}) :: { [Device]: { [string]: { [string]: boolean } } }

-- The column the gamepad reads for a Settings.ControllerType value.
function InputConfig.PadDevice(controllerType: unknown): Device
	return if controllerType == InputConfig.ControllerTypes.Shortcut then "GP" else "GC"
end

-- Whether `action` is one the device can trigger.
function InputConfig.IsAction(device: Device, action: unknown): boolean
	return type(action) == "string" and contexts[device][action] ~= nil
end

-- Whether two different actions of a device can be asked for at the same moment.
function InputConfig.Conflicts(device: Device, actionA: string, actionB: string): boolean
	local first, second = contexts[device][actionA], contexts[device][actionB]
	if not first or not second or actionA == actionB then
		return false
	end
	for context in first do
		if second[context] then
			return true
		end
	end
	return false
end

-- Whether `key` is a name `action` may be bound to on `device`: "None", or an accepted
-- key that the engine does not keep in any context of the action.
function InputConfig.CanBind(device: Device, action: string, key: unknown): boolean
	local where = contexts[device][action]
	if not where or type(key) ~= "string" then
		return false
	end
	if key == InputConfig.Unbound then
		return true
	end
	if not InputConfig.Keys[device][key] then
		return false
	end
	local reserved = InputConfig.Reserved[device]
	for context in where do
		local kept = reserved[context]
		if kept and kept[key] then
			return false
		end
	end
	return true
end

--[[
	The key in force for an action from what its profile row holds (`saved` is
	Hotkeys.<Action>.<device>, whatever it is). A name that is accepted, or "None", is
	itself. Anything else - a row from before the column existed, the "Unknown" the legacy
	template saved, a name that is no longer accepted - reads as the default. The server
	and the client both read through here, so a swap is decided on the keys the player sees.
]]
function InputConfig.ReadKey(device: Device, action: string, saved: unknown): string
	if type(saved) == "string" and (saved == InputConfig.Unbound or InputConfig.Keys[device][saved]) then
		return saved
	end
	local row = defaults[action]
	return if row then row[device] else InputConfig.Unbound
end

--[[
	Rebinding, decided in one place. `read(action)` answers the key in force for an action
	of the device (InputConfig.ReadKey over the profile). Every function returns the keys
	to write, { [action] = key }, or nil when the request is not allowed; nothing is
	written here. The server is the only caller that acts on the answer (HotkeyService).

	The rule they keep: after the change, no two actions that share a context hold the same
	key, and no action holds a key it may not have (InputConfig.CanBind).
]]
local function isConsistent(device: Device, read: (action: string) -> string, changes: { [string]: string }): boolean
	for action, key in changes do
		if not InputConfig.CanBind(device, action, key) then
			return false
		end
		if key ~= InputConfig.Unbound then
			for other in contexts[device] do
				if InputConfig.Conflicts(device, action, other) then
					local otherKey = changes[other]
					if otherKey == nil then
						otherKey = read(other)
					end
					if otherKey == key then
						return false
					end
				end
			end
		end
	end
	return true
end

--[[
	Binds `key` to `action`. Whoever held that key in a context of the action gets the
	action's previous key in exchange - a fruit menu button trades with the basic action
	and with the ability of each fruit that were on its new button. A second holder inside
	one context, which only a profile from before these rules can have, is left unbound.
	Refused when the exchange would put a key where
	it may not go - a fruit menu button onto ButtonA, an ability onto its own menu button.
]]
function InputConfig.PlanBind(
	device: Device,
	read: (action: string) -> string,
	action: string,
	key: string
): { [string]: string }?
	if not InputConfig.CanBind(device, action, key) then
		return nil
	end
	local changes: { [string]: string } = {}
	local previous = read(action)
	if previous == key then
		return changes
	end
	changes[action] = key
	if key ~= InputConfig.Unbound then
		-- Who already got the previous key: two of them that share a context cannot both.
		local given: { string } = {}
		for other in contexts[device] do
			if InputConfig.Conflicts(device, action, other) and read(other) == key then
				local free = true
				for _, holder in given do
					if InputConfig.Conflicts(device, holder, other) then
						free = false
						break
					end
				end
				changes[other] = if free then previous else InputConfig.Unbound
				if free then
					table.insert(given, other)
				end
			end
		end
	end
	return if isConsistent(device, read, changes) then changes else nil
end

-- Exchanges the keys of two actions that share a context.
function InputConfig.PlanSwap(
	device: Device,
	read: (action: string) -> string,
	actionA: string,
	actionB: string
): { [string]: string }?
	if not InputConfig.Conflicts(device, actionA, actionB) then
		return nil
	end
	local changes = { [actionA] = read(actionB), [actionB] = read(actionA) }
	return if isConsistent(device, read, changes) then changes else nil
end

-- Every action of the device back on its default key.
function InputConfig.PlanReset(device: Device): { [string]: string }
	local changes: { [string]: string } = {}
	for action in contexts[device] do
		changes[action] = defaults[action][device]
	end
	return changes
end

-- Buttons of the MobileContext layout (ContextButtonFrame.<name>), as the legacy scripts drove them.
local mobileButtons: { [string]: MobileButton } = {
	Button1 = { Action = "Dash", Skill = "Melee", Level = 50, Mode = "Tap", ActiveColor = Color3.new(0, 1, 0) },
	Button2 = { Action = "Shave", Skill = "Melee", Level = 200, Mode = "Tap", ActiveColor = Color3.new(0, 1, 0) },
	Button3 = {
		Action = "Haki",
		Skill = "Haki",
		Level = 200,
		Mode = "Toggle",
		ActiveColor = Color3.new(0.1, 0.05, 0.1),
		Status = "Haki",
	},
	Button4 = {
		Action = "Observation",
		Skill = "Haki",
		Level = 1,
		Mode = "Toggle",
		ActiveColor = Color3.new(0.2, 0.2, 0.6),
		Status = "UsingObs",
	},
	Button5 = { Action = "SpFn", Skill = "Sword", Level = 90, Mode = "Tap", ActiveColor = Color3.new(0.6, 0.5, 0.2) },
	-- Conqueror's Haki: from Haki 500, once a stage is held. Tinted while the coating is on.
	Button6 = {
		Action = "Conq",
		Skill = "Haki",
		Level = 500,
		Unlock = "Haki.ConquerorStage",
		Mode = "Toggle",
		ActiveColor = Color3.new(0.5, 0.05, 0.05),
		Status = "ConquerorCoating",
	},
}
-- A button whose action is switched off does not exist: nothing draws it, in play or in
-- the layout editor.
for name, button in mobileButtons do
	if button.Action and not InputConfig.IsEnabled(button.Action) then
		mobileButtons[name] = nil
	end
end
InputConfig.MobileButtons = table.freeze(mobileButtons)

return table.freeze(InputConfig)
