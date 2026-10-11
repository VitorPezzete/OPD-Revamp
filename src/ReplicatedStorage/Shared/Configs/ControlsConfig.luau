--!strict
--[[
	The vocabulary of the control layouts (Settings.Control_Layout), for players without a
	mouse:
		"Default"  the touch buttons as they always were;
		"Auto"     the same places and sizes, but each touch button behaves by what its
		           action is (the table Auto below). Nothing of it is the player's: nothing
		           is stored for it but the setting itself;
		"Custom"   what the player adjusted, inside the limits given here. The values
		           themselves are player data, the table "Controls":

		Controls = {
			CameraOffset = { X, Y, Z },        -- studs: right, up, back (away from the picture)
			AimOffset = { X, Y },              -- share of the viewport, added to the default aim point
			Buttons = {                        -- touch buttons the player changed, by id
				[id] = { X?, Y?, Scale, Behavior },
			},
		}

	Shared: the client applies and edits it (ControlsController, UI.Util.TouchControls, the
	ControlsEditor screen), the server validates every write against it
	(SettingsService.Client:SetControls). The server is the authority.

	Buttons. An id is the InputController action the button fires ("Lock" is the camera
	lock button). X and Y are the centre of the button as a share (0-1) of the usable
	screen - the area a ScreenGui gets: below the Roblox top bar, inside the device's safe
	insets. A share survives another resolution or a rotated screen, where pixels would
	not; whoever places the button clamps it so the whole disc stays inside that area. X and
	Y come as a pair or not at all: without them the button stays in its place of the default
	layout and only its size and behaviour are the player's.

	Behaviours: how a touch on the button becomes the action. They are a translation made
	on the client; the server sees the same action inputs whatever the behaviour. With
	"Custom" each button has the one the player chose, with "Auto" the one its action calls
	for; with "Default" the buttons are driven as they always were (abilities held, every
	other button by the engine's click, which comes when the finger lifts on the button).

	Aimed (Dash, Shave, Special):
		Arm        the button arms the action, the next tap on the world uses it there (default)
		Instant    used at the aim point the moment the button is touched
		Release    used at the aim point when the finger lifts
		DoubleTap  used at the aim point on the second touch within DoubleTapSeconds
	Toggle (Haki, Observation, Conqueror, Lock):
		Press      switches when the button is touched (default)
		Release    switches when the finger lifts
		DoubleTap  switches on the second touch within DoubleTapSeconds
	Ability (the twelve ability discs):
		Hold       finger down is key down, finger up is key up (default)
		Toggle     one touch presses the key, the next one lets it go
		DoubleTap  the key goes down on the second touch and up when that finger lifts
		Release    a quick cast: key down and up at once when the finger lifts
		Tap        a quick cast: key down and up at once when the button is touched

	Auto. A thumb cannot hold a button and turn the camera at once, so:
	- an aimed action is used at the aim cross the moment its button is touched (no second
	  tap on the world to spend);
	- a toggle switches on the touch;
	- an ability takes the behaviour of what its key does (FruitConfig.GetPress):
	  "Single" - the press is everything - is a Tap; "Charge" - held, the release is the
	  cast - is a Hold, since how long the finger stays is the charge; "Sustained" - it
	  lasts while the key is down - is a Toggle: one tap starts the stream, the next ends
	  it, and the thumb is free to turn the camera and aim it in between. The price: when
	  the server ends a stream by itself (a stun, the end of its ammunition) the button
	  still counts as down, and the next tap only lets go.
	The camera and aim offsets are not part of Auto: they are a taste, not something the
	kind of an action can decide, and they stay with "Custom".

		ControlsConfig.Default()                -> Controls, everything at rest
		ControlsConfig.Validate(payload)        -> Controls? (server: nil on anything wrong)
		ControlsConfig.Read(saved)              -> Controls  (client: keeps what is valid)
		ControlsConfig.NextBehavior(id, name)   -> the behaviour after `name` for that button
		ControlsConfig.AutoBehavior(id, press)  -> the behaviour "Auto" gives that button
]]

export type Kind = "Aimed" | "Toggle" | "Ability"
export type Range = { Min: number, Max: number }

export type ButtonEntry = {
	-- Centre of the button, share of the usable screen. Both or neither.
	X: number?,
	Y: number?,
	-- Multiplier of the button's default size.
	Scale: number,
	Behavior: string,
}

export type Controls = {
	CameraOffset: { X: number, Y: number, Z: number },
	AimOffset: { X: number, Y: number },
	Buttons: { [string]: ButtonEntry },
}

export type ButtonDefinition = {
	Kind: Kind,
	-- What the editor calls it.
	Label: string,
}

export type BehaviorSet = {
	Default: string,
	-- In cycling order.
	Allowed: { string },
	-- One line per behaviour, shown by the editor.
	Hints: { [string]: string },
}

local InputConfig = require(script.Parent.InputConfig)

local SLOT_LETTERS = { "A", "B", "C", "D", "E", "F" }
-- Stored numbers are rounded to this many decimals: a profile does not need more.
local PRECISION = 1000

local ControlsConfig = {}

-- Settings.<LayoutSetting>: only "Custom" reads the Controls table.
ControlsConfig.LayoutSetting = "Control_Layout"
ControlsConfig.Layouts = table.freeze({ Default = "Default", Auto = "Auto", Custom = "Custom" })

-- Studs, in the camera's own (level) frame: X to its right, Y up, Z back towards the viewer.
ControlsConfig.CameraOffset = table.freeze({
	X = table.freeze({ Min = -4, Max = 4 }),
	Y = table.freeze({ Min = -2, Max = 4 }),
	Z = table.freeze({ Min = -4, Max = 4 }),
	-- What one press of an editor arrow changes.
	Step = 0.5,
}) :: { X: Range, Y: Range, Z: Range, Step: number }

-- Share of the viewport, X to the right and Y down, from the device's default aim point.
ControlsConfig.AimOffset = table.freeze({
	X = table.freeze({ Min = -0.4, Max = 0.4 }),
	Y = table.freeze({ Min = -0.4, Max = 0.4 }),
	Step = 0.02,
}) :: { X: Range, Y: Range, Step: number }

ControlsConfig.Scale = table.freeze({ Min = 0.6, Max = 2, Default = 1, Step = 0.1 })
-- Share of the usable screen for a button's centre.
ControlsConfig.Position = table.freeze({ Min = 0, Max = 1 }) :: Range
-- Longest pause between the two touches of a double tap.
ControlsConfig.DoubleTapSeconds = 0.3

ControlsConfig.Behaviors = table.freeze({
	Aimed = table.freeze({
		Default = "Arm",
		Allowed = table.freeze({ "Arm", "Instant", "Release", "DoubleTap" }),
		Hints = table.freeze({
			Arm = "Touch the button, then tap where to use it.",
			Instant = "Used at the aim cross as soon as you touch it.",
			Release = "Used at the aim cross when you lift your finger.",
			DoubleTap = "Used at the aim cross on a double tap.",
		}),
	}),
	Toggle = table.freeze({
		Default = "Press",
		Allowed = table.freeze({ "Press", "Release", "DoubleTap" }),
		Hints = table.freeze({
			Press = "Switches as soon as you touch it.",
			Release = "Switches when you lift your finger.",
			DoubleTap = "Switches on a double tap.",
		}),
	}),
	Ability = table.freeze({
		Default = "Hold",
		Allowed = table.freeze({ "Hold", "Toggle", "DoubleTap", "Release", "Tap" }),
		Hints = table.freeze({
			Hold = "Held while your finger is on it.",
			Toggle = "One tap holds it, the next tap lets go.",
			DoubleTap = "Double tap and keep the finger down to hold it.",
			Release = "A quick cast when you lift your finger.",
			Tap = "A quick cast as soon as you touch it.",
		}),
	}),
}) :: { [Kind]: BehaviorSet }

--[[
	The "Auto" layout: the behaviour of a button from what its action is (see the header).
	Aimed and Toggle buttons have one each; an ability button has one per way an ability
	can use its key (FruitConfig.Press). Every name here is one its kind allows.
]]
ControlsConfig.Auto = table.freeze({
	Aimed = "Instant",
	Toggle = "Press",
	Ability = table.freeze({
		Single = "Tap",
		Charge = "Hold",
		Sustained = "Toggle",
	}),
}) :: { Aimed: string, Toggle: string, Ability: { [string]: string } }

local buttons: { [string]: ButtonDefinition } = {
	Dash = { Kind = "Aimed", Label = "Dash" },
	Shave = { Kind = "Aimed", Label = "Shave" },
	SpFn = { Kind = "Aimed", Label = "Special" },
	Haki = { Kind = "Toggle", Label = "Haki" },
	Observation = { Kind = "Toggle", Label = "Observation" },
	Conq = { Kind = "Toggle", Label = "Conqueror" },
	Lock = { Kind = "Toggle", Label = "Camera Lock" },
}
-- In the order the editor lists them.
local order: { string } = { "Dash", "Shave", "SpFn", "Haki", "Observation", "Conq", "Lock" }
for fruitSlot = 1, 2 do
	for abilitySlot, letter in SLOT_LETTERS do
		-- The same names InputConfig.GetAbilityAction gives the ability actions.
		local id = `DF{fruitSlot}{letter}`
		buttons[id] = { Kind = "Ability", Label = `Fruit {fruitSlot} ability {abilitySlot}` }
		table.insert(order, id)
	end
end
-- The ids stay known while their action is switched off (a saved layout that names one
-- stays valid); they only leave the editor's list.
for index = #order, 1, -1 do
	if not InputConfig.IsEnabled(order[index]) then
		table.remove(order, index)
	end
end
for _, definition in buttons do
	table.freeze(definition)
end

ControlsConfig.Buttons = table.freeze(buttons)
ControlsConfig.ButtonOrder = table.freeze(order)

local CAMERA_AXES = { "X", "Y", "Z" }
local AIM_AXES = { "X", "Y" }
local TOP_KEYS: { [string]: boolean } = { CameraOffset = true, AimOffset = true, Buttons = true }
local ENTRY_KEYS: { [string]: boolean } = { X = true, Y = true, Scale = true, Behavior = true }

local function round(value: number): number
	return math.round(value * PRECISION) / PRECISION
end

-- A real number: not a string that looks like one, not NaN, not an infinity.
local function isFinite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

--[[
	The number, when it is one and inside the range. Strict: nil for anything else.
	Lenient: a finite number is brought into the range; anything else is nil.
]]
local function number(value: unknown, range: Range, strict: boolean): number?
	if not isFinite(value) then
		return nil
	end
	local real = value :: number
	if real < range.Min or real > range.Max then
		if strict then
			return nil
		end
		real = math.clamp(real, range.Min, range.Max)
	end
	return round(real)
end

-- Whether `source` holds nothing but the listed string keys (it is never walked further
-- than one key past them, whatever its size).
local function onlyKeys(source: { [any]: any }, allowed: { [string]: boolean }, limit: number): boolean
	local count = 0
	for key in source do
		count += 1
		if count > limit or type(key) ~= "string" or not allowed[key] then
			return false
		end
	end
	return true
end

-- { X, Y(, Z) } inside `ranges`. Strict: nil unless it is exactly that.
local function offset(source: unknown, axes: { string }, ranges: { [string]: any }, strict: boolean): { [string]: number }?
	local clean: { [string]: number } = {}
	if type(source) ~= "table" then
		if strict then
			return nil
		end
		for _, axis in axes do
			clean[axis] = 0
		end
		return clean
	end

	local known: { [string]: boolean } = {}
	for _, axis in axes do
		known[axis] = true
	end
	if strict and not onlyKeys(source :: any, known, #axes) then
		return nil
	end
	for _, axis in axes do
		local value = number((source :: any)[axis], ranges[axis], strict)
		if value == nil then
			if strict then
				return nil
			end
			value = 0
		end
		clean[axis] = value :: number
	end
	return clean
end

-- One button. Returns (entry, valid): entry is nil for a button left as the default one.
local function entry(id: string, source: unknown, strict: boolean): (ButtonEntry?, boolean)
	local definition = buttons[id]
	if not definition or type(source) ~= "table" then
		return nil, false
	end
	local raw = source :: any
	if strict and not onlyKeys(raw, ENTRY_KEYS, 4) then
		return nil, false
	end

	local behaviors = ControlsConfig.Behaviors[definition.Kind]
	local behavior = raw.Behavior
	if type(behavior) ~= "string" or not table.find(behaviors.Allowed, behavior) then
		if strict then
			return nil, false
		end
		behavior = behaviors.Default
	end

	local scale = number(raw.Scale, ControlsConfig.Scale, strict)
	if scale == nil then
		if strict then
			return nil, false
		end
		scale = ControlsConfig.Scale.Default
	end

	local x: number? = nil
	local y: number? = nil
	if raw.X ~= nil or raw.Y ~= nil then
		x = number(raw.X, ControlsConfig.Position, strict)
		y = number(raw.Y, ControlsConfig.Position, strict)
		if x == nil or y == nil then
			if strict then
				return nil, false
			end
			-- Half a position is no position: the button goes back to its default place.
			x, y = nil, nil
		end
	end

	-- Nothing of it differs from the default button: not worth storing.
	if x == nil and scale == ControlsConfig.Scale.Default and behavior == behaviors.Default then
		return nil, true
	end
	return { X = x, Y = y, Scale = scale :: number, Behavior = behavior }, true
end

local function build(source: unknown, strict: boolean): Controls?
	if type(source) ~= "table" then
		return if strict then nil else ControlsConfig.Default()
	end
	local raw = source :: any
	if strict and not onlyKeys(raw, TOP_KEYS, 3) then
		return nil
	end

	local camera = offset(raw.CameraOffset, CAMERA_AXES, ControlsConfig.CameraOffset, strict)
	local aim = offset(raw.AimOffset, AIM_AXES, ControlsConfig.AimOffset, strict)
	if not camera or not aim then
		return nil
	end

	local clean: { [string]: ButtonEntry } = {}
	local saved = raw.Buttons
	if type(saved) == "table" then
		-- Read by known id, never by walking what was sent: a huge table costs nothing more.
		for _, id in order do
			local value = saved[id]
			if value ~= nil then
				local button, valid = entry(id, value, strict)
				if strict and not valid then
					return nil
				end
				if button then
					clean[id] = button
				end
			end
		end
		if strict then
			-- Anything else in there is not ours: an unknown id, a number key, too many keys.
			local count = 0
			for key in saved do
				count += 1
				if count > #order or type(key) ~= "string" or not buttons[key] then
					return nil
				end
			end
		end
	elseif strict then
		return nil
	end

	return {
		CameraOffset = { X = camera.X, Y = camera.Y, Z = camera.Z },
		AimOffset = { X = aim.X, Y = aim.Y },
		Buttons = clean,
	}
end

-- Everything at rest: no offsets, every button the default one.
function ControlsConfig.Default(): Controls
	return {
		CameraOffset = { X = 0, Y = 0, Z = 0 },
		AimOffset = { X = 0, Y = 0 },
		Buttons = {},
	}
end

--[[
	Server side. A freshly built Controls holding nothing but what was checked, or nil when
	the payload is not exactly a Controls: a wrong type anywhere, a key that is not part of
	the shape, an unknown button id, a number that is not finite or is out of its range, a
	behaviour its button does not have, a position with only one coordinate. Nothing of the
	payload itself is kept.
]]
function ControlsConfig.Validate(payload: unknown): Controls?
	return build(payload, true)
end

--[[
	Client side, for what the profile holds: never fails. What is valid is kept (numbers
	brought into range), what is not is dropped - a button id of another version of the
	game, a field of the wrong type - and a missing table reads as the default one.
]]
function ControlsConfig.Read(saved: unknown): Controls
	return build(saved, false) or ControlsConfig.Default()
end

-- The behaviour of a button nobody changed.
function ControlsConfig.DefaultBehavior(id: string): string
	local definition = buttons[id]
	return if definition then ControlsConfig.Behaviors[definition.Kind].Default else ""
end

--[[
	The behaviour the "Auto" layout gives a button. `press` is how the ability on an ability
	button uses its key (FruitConfig.GetPress); nil - an empty slot, a fruit this version
	does not know - reads as the default behaviour of ability buttons.
]]
function ControlsConfig.AutoBehavior(id: string, press: string?): string
	local definition = buttons[id]
	if not definition then
		return ""
	end
	if definition.Kind == "Ability" then
		return (if press then ControlsConfig.Auto.Ability[press] else nil) or ControlsConfig.Behaviors.Ability.Default
	end
	return if definition.Kind == "Aimed" then ControlsConfig.Auto.Aimed else ControlsConfig.Auto.Toggle
end

-- The behaviour after `current` for that button (wraps around).
function ControlsConfig.NextBehavior(id: string, current: string): string
	local definition = buttons[id]
	if not definition then
		return current
	end
	local allowed = ControlsConfig.Behaviors[definition.Kind].Allowed
	local index = table.find(allowed, current) or 0
	return allowed[index % #allowed + 1]
end

-- The one-line explanation of a behaviour of that button, for the editor.
function ControlsConfig.BehaviorHint(id: string, behavior: string): string
	local definition = buttons[id]
	if not definition then
		return ""
	end
	return ControlsConfig.Behaviors[definition.Kind].Hints[behavior] or ""
end

-- `value` moved by `steps` steps of `step`, kept on the grid and inside the range.
function ControlsConfig.Step(value: number, steps: number, step: number, range: Range): number
	local moved = math.round((value + steps * step) / step) * step
	return round(math.clamp(moved, range.Min, range.Max))
end

return table.freeze(ControlsConfig)
