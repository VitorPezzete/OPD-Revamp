--!strict
--[[
	Gamepad helper panels (legacy ControllerGui), bottom-right corner, for the Advanced
	controller layout (Settings.ControllerType = "Shortcut"):

	- Mode2, the controls panel: the two fruit menus and every basic action of the layout
	  (InputConfig.PadActions.GP), each with the picture of its button;
	- Menu1 / Menu2 above it, shown while that fruit's menu button is held: the six
	  abilities of the fruit, each with the picture of the button that fires it.

	The old look: small flat panels of lines, one line per action on a lighter stripe; the
	controls panel with a black border (gone: no panel is outlined now). They are a column in the corner now, every line the
	same height with its picture in a column of its own, in the legacy text style (the old
	lines were black text stretched to each stripe). All three panels are the blue of the
	buttons: the old red, yellow and mint hid the pictures of the pad's buttons.

	The whole panel shows only while a gamepad is the device in use and the layout is
	Advanced (the Classic layout has no menus: its selection is shown on the ability bar).

	The buttons are the player's own (Hotkeys.<Action>.GP, read through InputConfig.ReadKey
	like InputController does, so a profile that holds nothing valid shows the default) and
	follow every rebinding made in the settings; the pictures come from the engine, for the
	pad in use (UI.Util.PadIcons). An action left without a button shows no picture. All of
	it mirrors InputController, which owns the state.

	What the old panel was drawn for is gone: six fixed lines ("Devil Fruit Menu 1" ...
	"Haki") and a second copy of them, Mode1, for a "Default" mode two more buttons switched
	to. The Advanced layout is always in its ability mode now, so Mode1 is not built, and
	Mode2 has one line per action of today, the panel as tall as they need. The pictures
	are new: the legacy panel never said which button did what.

	The legacy panel was driven from three places (ControllerBinds, CoreModule and one label
	script per ability that read the name from the fruit's script instances).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local PadIcons = require(ReplicatedStorage.Client.UI.Util.PadIcons)

type Scope = Fusion.Scope<typeof(Fusion)>

local NO_ABILITY = "None"
local ABILITY_SLOTS = 6

-- Design pixels of a 1920x1080 screen. The old panels were a fifth of the screen's height
-- wide; a little more, for the pictures.
local PANEL_WIDTH = 236
local LINE_HEIGHT = 26
local LINE_GAP = 2
local PANEL_PADDING = Kit.Space.XS
local EDGE_MARGIN = 4
local STRIPE_TRANSPARENCY = 0.75
-- Every panel is the blue of the buttons. The old ones were red, yellow and mint, and the
-- white pictures of the pad's buttons could not be seen on the pale ones.
local PANEL_COLOR = Kit.Colors.Blue

-- The column of the Hotkeys rows this panel reads: the Advanced layout's.
local DEVICE: InputConfig.Device = "GP"

-- The lines of the controls panel: the fruit menus and the basic actions, in the order
-- the settings list them. The abilities have the menu panels.
local ACTIONS: { { Text: string, Action: string } } = {}
for _, entry in InputConfig.PadActions[DEVICE] do
	if entry.Menu or not entry.Fruit then
		table.insert(ACTIONS, { Text = entry.Label, Action = entry.Action })
	end
end

local function panelHeight(lines: number): number
	return lines * LINE_HEIGHT + math.max(0, lines - 1) * LINE_GAP + 2 * PANEL_PADDING
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
		local function buttonOf(action: string): Fusion.Computed<string>
			return scope:Computed(function(use): string
				local all = use(hotkeys)
				local entry = if type(all) == "table" then all[action] else nil
				local button = InputConfig.ReadKey(DEVICE, action, if type(entry) == "table" then entry[DEVICE] else nil)
				return if button ~= InputConfig.Unbound then button else ""
			end)
		end

		-- A stripe: the picture of the button in a square on the left, the text beside it.
		local function line(props: {
			Name: string,
			Order: number,
			Text: Fusion.UsedAs<string>,
			Color: Fusion.UsedAs<Color3>?,
			Button: Fusion.UsedAs<string>,
		}): Instance
			local image = scope:Computed(function(use): string
				return PadIcons.image(use(props.Button))
			end)
			return Kit.Well(scope, {
				Name = props.Name,
				Color = Kit.Colors.Box,
				Transparency = STRIPE_TRANSPARENCY,
				Size = UDim2.new(1, 0, 0, LINE_HEIGHT),
				LayoutOrder = props.Order,
				Children = {
					Kit.Image(scope, {
						Name = "Button",
						Image = image,
						Position = UDim2.fromOffset(1, 1),
						Size = UDim2.fromOffset(LINE_HEIGHT - 2, LINE_HEIGHT - 2),
						Visible = scope:Computed(function(use): boolean
							return use(image) ~= ""
						end),
					}),
					Kit.Label(scope, {
						Name = "Text",
						Text = props.Text,
						Color = props.Color,
						TextSize = Kit.TextSize.Small,
						Fit = true,
						Position = UDim2.fromOffset(LINE_HEIGHT + Kit.Space.XS, 0),
						-- The same room is left on the right, so the text is centred on the stripe.
						Size = UDim2.new(1, -2 * (LINE_HEIGHT + Kit.Space.XS), 1, 0),
					}),
				},
			})
		end

		local function panel(props: {
			Name: string,
			Order: number,
			Color: Color3,
			Visible: Fusion.UsedAs<boolean>?,
			Lines: { Instance },
		}): Instance
			return Kit.Panel(scope, {
				Name = props.Name,
				Image = "",
				Color = props.Color,
				Transparency = 0,
				Size = UDim2.fromOffset(PANEL_WIDTH, panelHeight(#props.Lines)),
				LayoutOrder = props.Order,
				Visible = props.Visible,
				Children = {
					Kit.Stack(scope, {
						Name = "Lines",
						Size = UDim2.fromScale(1, 1),
						Gap = LINE_GAP,
						Padding = PANEL_PADDING,
						Children = props.Lines,
					}),
				} :: { any },
			})
		end

		---------------------------------------------------------------------------------
		-- Controls panel: one line per action.

		local controlLines: { Instance } = {}
		for index, action in ACTIONS do
			table.insert(
				controlLines,
				line({ Name = action.Action, Order = index, Text = action.Text, Button = buttonOf(action.Action) })
			)
		end

		local panels: { Instance } = {
			panel({
				Name = "Mode2",
				-- Under the menus.
				Order = 3,
				Color = PANEL_COLOR,
				Lines = controlLines,
			}),
		}

		---------------------------------------------------------------------------------
		-- Menu panels: the abilities of the fruit whose menu button is held.

		for fruitSlot = 1, 2 do
			local fruitName = Bind.data(scope, `DevilFruits.Slot{fruitSlot}.Name`, NO_ABILITY)
			local abilityLines: { Instance } = {}
			for abilitySlot = 1, ABILITY_SLOTS do
				local abilityName = scope:Computed(function(use): string?
					local fruit = use(fruitName)
					local definition = if type(fruit) == "string" then FruitConfig.GetAbility(fruit, abilitySlot) else nil
					return if definition then definition.Name else nil
				end)
				table.insert(
					abilityLines,
					line({
						Name = `Power{abilitySlot}`,
						Order = abilitySlot,
						Text = scope:Computed(function(use): string
							return use(abilityName) or NO_ABILITY
						end),
						-- A slot with no ability is greyed.
						Color = scope:Computed(function(use): Color3
							return if use(abilityName) then Kit.Colors.Text else Kit.Colors.TextDim
						end),
						-- The action of this slot in this fruit's menu (DF1A.. / DF2A..).
						Button = buttonOf(InputConfig.GetAbilityAction(fruitSlot, abilitySlot)),
					})
				)
			end

			table.insert(
				panels,
				panel({
					Name = `Menu{fruitSlot}`,
					Order = fruitSlot,
					Color = PANEL_COLOR,
					Lines = abilityLines,
					Visible = scope:Computed(function(use): boolean
						return use(heldMenu) == fruitSlot
					end),
				})
			)
		end

		-- Room for the controls and one menu above them (one menu button is held at a time).
		local height = panelHeight(#ACTIONS) + Kit.Space.S + panelHeight(ABILITY_SLOTS)

		return Kit.Screen(scope, {
			Name = "ControllerGui",
			Children = {
				Kit.Stack(scope, {
					Name = "Frame",
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -EDGE_MARGIN, 1, -EDGE_MARGIN),
					Size = UDim2.fromOffset(PANEL_WIDTH, height),
					Gap = Kit.Space.S,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Bottom,
					Visible = scope:Computed(function(use): boolean
						return use(hasCharacter)
							and use(usingGamepad) == true
							and use(controllerType) == InputConfig.ControllerTypes.Shortcut
					end),
					Children = panels,
				}),
			},
		})
	end,
}
