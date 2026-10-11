--!strict
--[[
	Gamepad helper panels, bottom-right corner, for the Advanced controller layout
	(Settings.ControllerType = "Shortcut"):

	- the controls panel: the two fruit menus and every basic action of the layout
	  (InputConfig.PadActions.GP), each with the picture of its button;
	- the menu panel above it, shown while a fruit's menu button is held: the six abilities
	  of that fruit, each with the picture of the button that fires it.

	Both show only while a gamepad is the device in use and the layout is Advanced (the
	Classic layout has no menus: its selection is shown on the ability bar).

	The buttons are the player's own (Hotkeys.<Action>.GP, read through InputConfig.ReadKey
	like InputController does, so a profile that holds nothing valid shows the default) and
	follow every rebinding made in the settings; the pictures come from the engine, for the
	pad in use (UI.Util.PadIcons). An action left without a button shows no picture. All of
	it mirrors InputController, which owns the state.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local PadIcons = require(ReplicatedStorage.Client.UI.Util.PadIcons)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local NO_ABILITY = "None"
local ABILITY_SLOTS = 6
local PANEL_WIDTH = 260
local ROW_HEIGHT = 26
local ICON_SIZE = 22
-- Above the version label.
local BOTTOM_MARGIN = 36
local RIGHT_MARGIN = 12

-- The column of the Hotkeys rows this panel reads: the Advanced layout's.
local DEVICE: InputConfig.Device = "GP"

-- The lines of the controls panel: the fruit menus and the basic actions, in the order
-- the settings list them. The abilities have the menu panel.
local ACTIONS: { { Text: string, Action: string } } = {}
for _, entry in InputConfig.PadActions[DEVICE] do
	if entry.Menu or not entry.Fruit then
		table.insert(ACTIONS, { Text = entry.Label, Action = entry.Action })
	end
end

local function heading(scope: Scope, text: Fusion.UsedAs<string>, order: number): Instance
	return UI.Label(scope, {
		Name = "Heading",
		Text = text,
		Variant = "Tiny",
		Font = Theme.Fonts.Heading,
		Color = Theme.Colors.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		LayoutOrder = order,
	})
end

-- One line: the picture of a button, then what it does.
local function line(
	scope: Scope,
	name: string,
	button: Fusion.UsedAs<string>,
	text: Fusion.UsedAs<string>,
	color: Fusion.UsedAs<Color3>,
	order: number
): Instance
	local image = scope:Computed(function(use): string
		return PadIcons.image(use(button))
	end)
	return scope:New("Frame")({
		Name = name,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		[Fusion.Children] = {
			UI.Image(scope, {
				Name = "Button",
				Image = image,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				Visible = scope:Computed(function(use): boolean
					return use(image) ~= ""
				end),
			}),
			UI.Label(scope, {
				Name = "Text",
				Text = text,
				Variant = "Small",
				Color = color,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(ICON_SIZE + Theme.Space.S, 0),
				Size = UDim2.new(1, -(ICON_SIZE + Theme.Space.S), 1, 0),
			}),
		},
	})
end

local function panel(scope: Scope, name: string, order: number, visible: Fusion.UsedAs<boolean>, rows: { Instance }): Instance
	return UI.Panel(scope, {
		Name = name,
		Size = UDim2.fromOffset(PANEL_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
		Visible = visible,
		Color = Theme.Colors.Background,
		Transparency = Theme.Transparency.Hud,
		Padding = Theme.Space.M,
		Children = {
			UI.Stack(scope, {
				Name = "Rows",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Gap = 0,
				Children = rows,
			}),
		},
	})
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local InputController = Knit.GetController("InputController")

		-- A Fusion value following one of InputController's signals.
		local function follow(signal: any, initial: any): Fusion.Value<any>
			local value = scope:Value(initial)
			local connection = signal:Connect(function(current: any)
				value:set(current)
			end)
			table.insert(scope, function()
				connection:Disconnect()
			end)
			return value
		end

		local usingGamepad = follow(InputController.DeviceChanged, InputController:IsUsingGamepad())
		-- The panel is for a player in the world: not on the spawn menu.
		local hasCharacter = scope:Value(LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			hasCharacter:set(character ~= nil)
		end))
		local heldMenu = follow(InputController.MenuChanged, InputController:GetHeldMenu())
		local controllerType = Bind.data(scope, "Settings.ControllerType", InputConfig.ControllerTypes.Legacy)
		local hotkeys = Bind.data(scope, "Hotkeys", {})

		-- Name of the gamepad button bound to an action ("" when none).
		local function buttonOf(action: Fusion.UsedAs<string?>): Fusion.Computed<string>
			return scope:Computed(function(use): string
				local name = use(action)
				local all = use(hotkeys)
				if not name then
					return ""
				end
				local entry = if type(all) == "table" then all[name] else nil
				local button = InputConfig.ReadKey(DEVICE, name, if type(entry) == "table" then entry[DEVICE] else nil)
				return if button ~= InputConfig.Unbound then button else ""
			end)
		end

		local fruitNames = {
			Bind.data(scope, "DevilFruits.Slot1.Name", NO_ABILITY),
			Bind.data(scope, "DevilFruits.Slot2.Name", NO_ABILITY),
		}
		-- Name of the fruit whose menu is held, nil while no menu is.
		local menuFruit = scope:Computed(function(use): string?
			local slot = use(heldMenu)
			local name = if type(slot) == "number" then fruitNames[slot] else nil
			return if name then use(name) else nil
		end)

		local menuRows: { Instance } = {
			heading(
				scope,
				scope:Computed(function(use): string
					return string.upper(`{use(menuFruit) or NO_ABILITY} - fruit {use(heldMenu) or ""}`)
				end),
				0
			),
		}
		for abilitySlot = 1, ABILITY_SLOTS do
			local abilityName = scope:Computed(function(use): string?
				local fruit = use(menuFruit)
				local definition = if fruit then FruitConfig.GetAbility(fruit, abilitySlot) else nil
				return if definition then definition.Name else nil
			end)
			-- The action of this slot in the held menu (DF1A.. / DF2A..).
			local action = scope:Computed(function(use): string?
				local slot = use(heldMenu)
				return if type(slot) == "number" then InputConfig.GetAbilityAction(slot, abilitySlot) else nil
			end)
			table.insert(
				menuRows,
				line(
					scope,
					`Power{abilitySlot}`,
					buttonOf(action),
					scope:Computed(function(use): string
						return use(abilityName) or NO_ABILITY
					end),
					scope:Computed(function(use): Color3
						return if use(abilityName) then Theme.Colors.Text else Theme.Colors.TextDim
					end),
					abilitySlot
				)
			)
		end

		local controlRows: { Instance } = { heading(scope, "CONTROLS", 0) }
		for index, action in ACTIONS do
			table.insert(
				controlRows,
				line(scope, action.Action, buttonOf(action.Action), action.Text, Theme.Colors.Text, index)
			)
		end

		return UI.Screen(scope, {
			Name = "ControllerGui",
			Children = {
				UI.Stack(scope, {
					Name = "Panels",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -RIGHT_MARGIN, 1, -BOTTOM_MARGIN),
					Gap = Theme.Space.S,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					Visible = scope:Computed(function(use): boolean
						return use(hasCharacter)
							and use(usingGamepad) == true
							and use(controllerType) == InputConfig.ControllerTypes.Shortcut
					end),
					Children = {
						panel(
							scope,
							"Menu",
							1,
							scope:Computed(function(use): boolean
								return use(heldMenu) ~= nil
							end),
							menuRows
						),
						panel(scope, "Controls", 2, true, controlRows),
					},
				}),
			},
		})
	end,
}
