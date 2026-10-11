--!strict
--[[
	Menu tab "Settings": keybinds, options and the stat reset button, on the parchment of
	the old menu and in its arrangement, built with the Kit.

	Keybinds       on top: two lists behind a device switch, Keyboard and Controller, with
	               "Defaults" beside it for the list in view (UI.Legacy.Components.KeybindList).
	Options        below: music volume, the two side panels, player list, join messages,
	               auto menu, hide bounty, the settings reset button (two clicks: every
	               option back to its default) and, last and in red, the stat reset
	               button (its own screen, "ResetStats").
	Optimization   side panel, right of the parchment: damage numbers, damage counter,
	               observation mode, Fast Mode (the legacy low graphics: Off, On, Extreme)
	               and the hitbox preview.
	More Options   side panel the old game did not have, for the settings that came with the
	               rework: the interface (UI Style: Rework / Legacy - the way back to the rework's -
	               and UI Scale), Tap to Charge, Aim Assist, Trade Requests, Camera Lock, Root
	               Lock and the control layout. It opens in the place of the other one.

	Every label is derived from the replicated Settings table, in the old "Name: Value"
	wording; a click only asks SettingsController for the next value (the server validates
	and stores it), so the tab shows what is saved, not what was clicked. What a setting
	does is applied elsewhere. A setting that is on lights its plank a little, as the old
	buttons did.

	The control layout (Settings.Control_Layout: "Default", "Auto" or "Custom") is for
	players without a mouse: its button shows on a touch screen or while a gamepad is the
	device in use, steps through the three, and while the layout is "Custom" the
	"Customize" button under it closes the menu tab and opens the controls editor (screen
	"ControlsEditor").

	Help. The old menu had no room for descriptions: what a setting does is written in a
	box under the side panel (beside the parchment while none is open) while the mouse, the
	gamepad selection or a finger is on its button. The rest of the time the box holds the
	line of help of the keybind list in view.

	Left out, because nothing reads them any more: Sun Mode and Fog. Left out, because the
	old menu had no code behind them: "Toggle Observation", "Raid Invites" and the
	inventory view.

	A menu part (see the shell): returns its panel, which the shell docks.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local SettingsConfig = require(ReplicatedStorage.Shared.Configs.SettingsConfig)
local TradeConfig = require(ReplicatedStorage.Shared.Configs.TradeConfig)
local UIConfig = require(ReplicatedStorage.Shared.Configs.UIConfig)
local KeybindList = require(ReplicatedStorage.Client.UI.Legacy.Components.KeybindList)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)

type Scope = Fusion.Scope<typeof(Fusion)>

local peek = Fusion.peek

-- Key of this tab (PlaceManifest.MenuTabs, menu.Selected).
local TAB = "Settings"

local RESET_SCREEN = "ResetStats"
-- The control layout: its setting, the value that has an editor, and the editor's screen.
local LAYOUT_SETTING = ControlsConfig.LayoutSetting
local CUSTOM_LAYOUT = ControlsConfig.Layouts.Custom
local DEFAULT_LAYOUT = ControlsConfig.Layouts.Default
local EDITOR_SCREEN = "ControlsEditor"
-- Settings.UI_Style when the profile holds something that is not a style.
local DEFAULT_STYLE = SettingsConfig.Definitions.UI_Style.Default
-- Settings.Camera_Lock: how hard the camera is pulled towards the locked target.
local CAMERA_LOCK_LABELS = { [0] = "Off", [1] = "Soft", [2] = "Medium", [3] = "Strong" }

-- The descriptions of the rework's settings tab.
local CONTROL_LAYOUT_HINT = "Touch buttons. Default: as they are. Auto: each button behaves by what its action is "
	.. "(a single cast on touch, hold to charge, tap on and off for what lasts). "
	.. "Custom: move, resize and set each button yourself, and offset the camera and the aim."
local CAMERA_LOCK_HINT = "Gamepad and touch: keeps the camera on a target. Switched with the Camera Lock button "
	.. "of your controller (Keybinds) or the lock button on the screen."
local ROOT_LOCK_HINT = "Gamepad and touch only: your character always faces where the camera looks."
local AUTO_MENU_HINT = "Closes the shop when you move."
local AIM_ASSIST_HINT = "Gamepad and touch only."
local TRADE_HINT = "Lets other players invite you to trade."
local UI_STYLE_HINT = "Rework is the new interface. Legacy is the old game's, with the new health bar and player list."
local UI_SCALE_HINT = "Enlarges the whole interface."
local CHARGE_HINT = "Chargeable abilities start on one press and release on the next, instead of holding."
local STATS_HINT = "Wipes your stats, Beri, fruits and items."
-- What SettingsService.Client:Reset does and leaves alone.
local RESET_SETTINGS = "Reset Settings"
local RESET_SETTINGS_CONFIRM = "Click again to reset"
local RESET_SETTINGS_HINT = "Puts every option back to its default. Keybinds, UI Style and your custom button layout stay."
-- Seconds the reset button waits for its second click.
local RESET_CONFIRM_SECONDS = 4
-- What StatResetService:ResetStats wipes (the legacy tip said "Resets ALL data.").
local RESET_TIP = "Resets your combat stats, Haki, Beri, bounty and kills, and removes your devil fruits and items."

-- The side panels.
local OPTIMIZATION = "Optimization"
local MORE = "More"
local SIDE_TITLES: { [string]: string } = { [OPTIMIZATION] = "Optimization", [MORE] = "More Options" }

-- The keybind lists.
local KEYBOARD = "Keyboard"
local CONTROLLER = "Controller"

-- Design pixels. The old tab: a parchment 414 wide and 979 tall, its side panel 350 wide.
local GAP = Kit.Space.S
local PAD = Kit.Space.M
local MAIN_SIZE = Vector2.new(440, 920)
local HEADING_HEIGHT = 34
local DEVICE_HEIGHT = 36
local DEVICE_WIDTH = 130
local OPTION_HEIGHT = 40
local OPTION_GAP = 6
-- Rows under "Options": the music stepper and eight buttons.
local OPTION_ROWS = 9
local OPTIONS_HEIGHT = OPTION_ROWS * OPTION_HEIGHT + (OPTION_ROWS - 1) * OPTION_GAP
-- What the two headings, the device switch, the options and the gaps between the five
-- leave to the keybind list.
local LIST_HEIGHT = MAIN_SIZE.Y - PAD * 2 - HEADING_HEIGHT * 2 - DEVICE_HEIGHT - OPTIONS_HEIGHT - GAP * 4
-- The side panel holds its title and up to nine buttons ("More Options" without a mouse).
local SIDE_ROWS = 9
local SIDE_SIZE = Vector2.new(360, PAD * 2 + HEADING_HEIGHT + SIDE_ROWS * (OPTION_HEIGHT + OPTION_GAP))
local HELP_HEIGHT = 150
local STEP_BUTTON = Vector2.new(40, 30)
-- How much a setting that is on lightens the tint under its plank.
local LIT_TRANSPARENCY = 0.7

local function onOff(value: any): string
	return if value == true then "On" else "Off"
end

local function isTrue(value: any): boolean
	return value == true
end

type Option = {
	Name: string,
	LayoutOrder: number,
	Text: Fusion.UsedAs<string>,
	OnClick: () -> (),
	Variant: Kit.Variant?,
	Visible: Fusion.UsedAs<boolean>?,
	-- Green text: the button of the side panel that is open.
	Selected: Fusion.UsedAs<boolean>?,
	-- State: the setting is on.
	Lit: Fusion.StateObject<boolean>?,
	Help: string?,
}

return function(scope: Scope, context: any, menu: any): GuiObject?
	local SettingsController = Knit.GetController("SettingsController")
	local InputController = Knit.GetController("InputController")

	local tabOpen = scope:Computed(function(use): boolean
		return use(menu.Selected) == TAB
	end)

	local function setting(name: string): Fusion.Value<any>
		return Bind.data(scope, `Settings.{name}`, SettingsConfig.Definitions[name].Default)
	end

	local function cycle(name: string, backwards: boolean?)
		local promise = SettingsController:Cycle(name, backwards)
		if promise then
			promise:catch(warn)
		end
	end

	---------------------------------------------------------------------------------
	-- Help: the description of the setting under the mouse, the selection or the finger.

	local hint = scope:Value("")
	local function showHint(text: string)
		hint:set(text)
	end
	local function hideHint(text: string)
		-- A finger leaves a button as it presses it: its text stays to be read.
		if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			return
		end
		if peek(hint) == text then
			hint:set("")
		end
	end
	-- A tab closed under the cursor never fires MouseLeave.
	scope:Observer(tabOpen):onChange(function()
		hint:set("")
		if not peek(tabOpen) then
			Tooltip.hide()
		end
	end)

	---------------------------------------------------------------------------------
	-- Buttons

	-- A plank as wide as its column.
	local function optionButton(option: Option): TextButton
		local help = option.Help
		local lit = option.Lit
		return Kit.Button(scope, {
			Name = option.Name,
			Text = option.Text,
			Variant = option.Variant,
			TextSize = Kit.TextSize.Body,
			Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
			LayoutOrder = option.LayoutOrder,
			Visible = option.Visible,
			Selected = option.Selected,
			OnClick = function()
				if help then
					showHint(help)
				end
				option.OnClick()
			end,
			OnHover = if help
				then function(hovering: boolean)
					if hovering then
						showHint(help)
					else
						hideHint(help)
					end
				end
				else nil,
			-- Under the plank, where the old buttons changed colour.
			Children = if lit
				then scope:New("Frame")({
					Name = "Lit",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					ZIndex = 0,
					BackgroundTransparency = scope:Computed(function(use): number
						return if use(lit) then LIT_TRANSPARENCY else 1
					end),
				})
				else nil,
		})
	end

	type ValueOption = {
		Name: string,
		LayoutOrder: number,
		Setting: string,
		Label: string,
		Describe: (value: any) -> string,
		-- nil: a setting with no "on" (a choice between equals).
		IsOn: ((value: any) -> boolean)?,
		Visible: Fusion.UsedAs<boolean>?,
		Help: string?,
	}

	-- "<label>: <value>", stepping to the next value on a click; lit while IsOn says so.
	local function valueButton(option: ValueOption): TextButton
		local value = setting(option.Setting)
		local isOn = option.IsOn
		return optionButton({
			Name = option.Name,
			LayoutOrder = option.LayoutOrder,
			Visible = option.Visible,
			Help = option.Help,
			Text = scope:Computed(function(use): string
				return `{option.Label}: {option.Describe(use(value))}`
			end),
			Lit = if isOn
				then scope:Computed(function(use): boolean
					return isOn(use(value))
				end)
				else nil,
			OnClick = function()
				cycle(option.Setting)
			end,
		})
	end

	-- An on / off setting.
	local function toggleButton(
		name: string,
		order: number,
		settingName: string,
		label: string,
		help: string?,
		visible: Fusion.UsedAs<boolean>?
	): TextButton
		return valueButton({
			Name = name,
			LayoutOrder = order,
			Setting = settingName,
			Label = label,
			Describe = onOff,
			IsOn = isTrue,
			Help = help,
			Visible = visible,
		})
	end

	---------------------------------------------------------------------------------
	-- Side panels: one at a time, in the same place, on the same parchment.

	local sidePanel: Fusion.Value<string?> = scope:Value(nil :: string?)
	local function toggleSide(panel: string)
		sidePanel:set(if peek(sidePanel) == panel then nil else panel)
	end
	local function sideIs(panel: string): Fusion.StateObject<boolean>
		return scope:Computed(function(use): boolean
			return use(sidePanel) == panel
		end)
	end
	local inOptimization = sideIs(OPTIMIZATION)
	local inMore = sideIs(MORE)

	-- The control layout is for players without a mouse: a touch screen, or a gamepad in use.
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

	-- "Default", "Auto" or "Custom", and the way into the editor of the custom one.
	local controlLayout = setting(LAYOUT_SETTING)
	local layoutShown = scope:Computed(function(use): boolean
		return use(inMore) and use(noMouse)
	end)

	local sideButtons: { Instance } = {
		-- Optimization.
		toggleButton("Setting_DamageNumbersOff", 1, "Damage_Numbers", "Damage Numbers", nil, inOptimization),
		toggleButton("Setting_DamageCounter", 2, "Hit_Counter", "Damage Counter", nil, inOptimization),
		valueButton({
			Name = "Setting_ObsMode",
			LayoutOrder = 3,
			Setting = "Obs_Mode",
			Label = "Observation Mode",
			Visible = inOptimization,
			Describe = function(value: any): string
				return if type(value) == "string" and value ~= "" then value else "Full"
			end,
		}),
		valueButton({
			Name = "Setting_FastMode",
			LayoutOrder = 4,
			Setting = "Fast_Mode",
			Label = "Fast Mode",
			Visible = inOptimization,
			Describe = function(value: any): string
				return if type(value) == "string" and value ~= "" then value else "Off"
			end,
			IsOn = function(value: any): boolean
				return value == "On" or value == "Extreme"
			end,
		}),
		-- Not in the rework's tab, but still read by the server (AttackService).
		toggleButton("Setting_Hitbox", 5, "Hitbox", "Hitbox", nil, inOptimization),

		-- More Options. The way back to the rework's interface: first, where it cannot be missed.
		valueButton({
			Name = "Setting_UIStyle",
			LayoutOrder = 11,
			Setting = "UI_Style",
			Label = "UI Style",
			Visible = inMore,
			Help = UI_STYLE_HINT,
			Describe = function(value: any): string
				return if type(value) == "string" and UIConfig.Styles[value] then value else DEFAULT_STYLE
			end,
		}),
		valueButton({
			Name = "Setting_UIScale",
			LayoutOrder = 12,
			Setting = "UI_Scale",
			Label = "UI Scale",
			Visible = inMore,
			Help = UI_SCALE_HINT,
			Describe = function(value: any): string
				return math.floor(UIConfig.ScaleFor(value) * 100 + 0.5) .. "%"
			end,
			IsOn = function(value: any): boolean
				return value ~= 0
			end,
		}),
		toggleButton("Setting_ChargeToggle", 13, "Charge_Toggle", "Tap to Charge", CHARGE_HINT, inMore),
		toggleButton("Setting_AimAssist", 14, "Aim_Assist", "Aim Assist", AIM_ASSIST_HINT, inMore),
		valueButton({
			Name = "Setting_CameraLock",
			LayoutOrder = 16,
			Setting = "Camera_Lock",
			Label = "Camera Lock",
			Visible = inMore,
			Help = CAMERA_LOCK_HINT,
			Describe = function(value: any): string
				return CAMERA_LOCK_LABELS[value] or "Off"
			end,
			IsOn = function(value: any): boolean
				return value ~= 0
			end,
		}),
		toggleButton("Setting_RootLock", 17, "Root_Lock", "Root Lock", ROOT_LOCK_HINT, inMore),
		valueButton({
			Name = "Setting_ControlLayout",
			LayoutOrder = 18,
			Setting = LAYOUT_SETTING,
			Label = "Button Layout",
			Visible = layoutShown,
			Help = CONTROL_LAYOUT_HINT,
			Describe = function(value: any): string
				-- Anything that is not a layout (a profile of another version) reads as the default.
				return if type(value) == "string" and (ControlsConfig.Layouts :: any)[value] then value else DEFAULT_LAYOUT
			end,
			IsOn = function(value: any): boolean
				return value == CUSTOM_LAYOUT or value == ControlsConfig.Layouts.Auto
			end,
		}),
		optionButton({
			Name = "Customize",
			LayoutOrder = 19,
			Text = "Customize",
			Help = CONTROL_LAYOUT_HINT,
			Visible = scope:Computed(function(use): boolean
				return use(layoutShown) and use(controlLayout) == CUSTOM_LAYOUT
			end),
			OnClick = function()
				-- The editor needs the screen: the tab makes room for it.
				context.Open(EDITOR_SCREEN)
				menu.Close()
			end,
		}),
	}
	-- Trading switched off (TradeConfig.Enabled): nobody can invite, so there is nothing
	-- to refuse. Its place in the panel is its LayoutOrder, wherever it sits in the table.
	if TradeConfig.Enabled then
		table.insert(
			sideButtons,
			toggleButton("Setting_TradeRequests", 15, "Trade_Requests", "Trade Requests", TRADE_HINT, inMore)
		)
	end

	local side = Kit.Panel(scope, {
		Name = "Side",
		Position = UDim2.fromOffset(MAIN_SIZE.X + GAP, 0),
		Size = UDim2.fromOffset(SIDE_SIZE.X, SIDE_SIZE.Y),
		Padding = PAD,
		Visible = scope:Computed(function(use): boolean
			return use(sidePanel) ~= nil
		end),
		Children = Kit.Stack(scope, {
			Name = "Buttons",
			Size = UDim2.fromScale(1, 1),
			Gap = OPTION_GAP,
			Children = {
				Kit.Label(scope, {
					Name = "Header",
					LayoutOrder = 0,
					TextSize = Kit.TextSize.Heading,
					Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
					Text = scope:Computed(function(use): string
						return SIDE_TITLES[use(sidePanel) or ""] or ""
					end),
				}),
				sideButtons,
			} :: { any },
		}),
	})

	---------------------------------------------------------------------------------
	-- Keybinds: the device switch, then the list of that device. It opens on the device in
	-- use and stays where the player puts it: following the last input would pull the list
	-- away from someone who reaches for the mouse while rebinding the pad.

	local function deviceInUse(): string
		return if InputController:IsUsingGamepad() then CONTROLLER else KEYBOARD
	end
	local device = scope:Value(deviceInUse())
	scope:Observer(tabOpen):onChange(function()
		if peek(tabOpen) then
			device:set(deviceInUse())
		end
	end)
	local keyboardShown = scope:Computed(function(use): boolean
		return use(device) == KEYBOARD
	end)
	local controllerShown = scope:Computed(function(use): boolean
		return use(device) == CONTROLLER
	end)

	local keyboardList = KeybindList.keyboard(
		scope,
		scope:Computed(function(use): boolean
			return use(tabOpen) and use(keyboardShown)
		end),
		{ Size = UDim2.fromScale(1, 1), Visible = keyboardShown }
	)
	local controllerList = KeybindList.controller(
		scope,
		scope:Computed(function(use): boolean
			return use(tabOpen) and use(controllerShown)
		end),
		{ Size = UDim2.fromScale(1, 1), Visible = controllerShown }
	)

	local function deviceButton(name: string, order: number, shown: Fusion.StateObject<boolean>): TextButton
		return Kit.Button(scope, {
			Name = name,
			Text = name,
			TextSize = Kit.TextSize.Small,
			Size = UDim2.fromOffset(DEVICE_WIDTH, DEVICE_HEIGHT),
			LayoutOrder = order,
			Selected = shown,
			OnClick = function()
				device:set(name)
			end,
		})
	end

	local devices = Kit.Stack(scope, {
		Name = "Devices",
		Direction = "Horizontal",
		Gap = GAP,
		Size = UDim2.new(1, 0, 0, DEVICE_HEIGHT),
		LayoutOrder = 2,
		Children = {
			deviceButton(KEYBOARD, 1, keyboardShown),
			deviceButton(CONTROLLER, 2, controllerShown),
			-- The white box the old list had above its first row. Restores the list in view.
			Kit.Button(scope, {
				Name = "Defaults",
				Text = "Defaults",
				Variant = "Box",
				TextSize = Kit.TextSize.Small,
				Size = UDim2.new(1, -(DEVICE_WIDTH + GAP) * 2, 1, 0),
				LayoutOrder = 3,
				OnClick = function()
					if peek(controllerShown) then
						controllerList.Reset()
					else
						keyboardList.Reset()
					end
				end,
			}),
		},
	})

	---------------------------------------------------------------------------------
	-- Options

	-- Music volume: the arrows wrap around (20 -> 0 and 0 -> 20).
	local volume = setting("Music")
	local function stepButton(name: string, text: string, order: number, backwards: boolean): TextButton
		return Kit.Button(scope, {
			Name = name,
			Text = text,
			Variant = "Grey",
			Size = UDim2.fromOffset(STEP_BUTTON.X, STEP_BUTTON.Y),
			LayoutOrder = order,
			OnClick = function()
				cycle("Music", backwards)
			end,
		})
	end
	local music = Kit.Panel(scope, {
		Name = "MusicVolume",
		Image = Kit.Images.Plank,
		Color = Kit.Colors.Plank,
		Transparency = 0.7,
		Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
		LayoutOrder = 1,
		Children = Kit.Stack(scope, {
			Direction = "Horizontal",
			Gap = GAP,
			Size = UDim2.fromScale(1, 1),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Children = {
				Kit.Label(scope, {
					Name = "Label",
					Text = "Music:",
					Size = UDim2.fromOffset(170, OPTION_HEIGHT),
					LayoutOrder = 1,
				}),
				stepButton("MusicDown", "<", 2, true),
				Kit.Label(scope, {
					Name = "Volume",
					Size = UDim2.fromOffset(80, OPTION_HEIGHT),
					LayoutOrder = 3,
					Text = scope:Computed(function(use): string
						return tostring(use(volume))
					end),
				}),
				stepButton("MusicUp", ">", 4, false),
			},
		}),
	})

	-- Settings reset. Two clicks: the first one only arms the button, for a few seconds.
	local resetArmed = scope:Value(false)
	local resetStamp = 0
	local settingsResetButton = optionButton({
		Name = "SettingsReset",
		LayoutOrder = 8,
		Help = RESET_SETTINGS_HINT,
		Text = scope:Computed(function(use): string
			return if use(resetArmed) then RESET_SETTINGS_CONFIRM else RESET_SETTINGS
		end),
		Selected = resetArmed,
		OnClick = function()
			resetStamp += 1
			if peek(resetArmed) then
				resetArmed:set(false)
				SettingsController:Reset():catch(warn)
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

	-- Stat reset has its own screen; the button only opens it, with a warning on hover.
	local resetButton = optionButton({
		Name = "StatReset",
		LayoutOrder = 9,
		Text = "Reset Stats",
		Variant = "Red",
		Help = STATS_HINT,
		OnClick = function()
			context.Toggle(RESET_SCREEN)
		end,
	})
	Tooltip.attach(scope, resetButton, RESET_TIP)

	local options = Kit.Stack(scope, {
		Name = "Options",
		Gap = OPTION_GAP,
		Size = UDim2.new(1, 0, 0, OPTIONS_HEIGHT),
		LayoutOrder = 5,
		Children = {
			music,
			optionButton({
				Name = "Setting_Optimization",
				LayoutOrder = 2,
				Text = "Optimization Tab",
				Selected = inOptimization,
				OnClick = function()
					toggleSide(OPTIMIZATION)
				end,
			}),
			optionButton({
				Name = "Setting_More",
				LayoutOrder = 3,
				Text = "More Options",
				Selected = inMore,
				OnClick = function()
					toggleSide(MORE)
				end,
			}),
			toggleButton("Setting_PlayerList", 4, "Player_List", "Disable Player List"),
			toggleButton("Setting_JoinMessages", 5, "Join_Message", "Join Messages"),
			toggleButton("Setting_AutoMenu", 6, "Auto_Menu", "Auto Menu", AUTO_MENU_HINT),
			toggleButton("Setting_HideLevel", 7, "Hide_Bounty", "Hide Bounty"),
			settingsResetButton,
			resetButton,
		},
	})

	---------------------------------------------------------------------------------
	-- The help box.

	local help = scope:Computed(function(use): string
		local described = use(hint)
		if described ~= "" then
			return described
		end
		return if use(controllerShown) then use(controllerList.Help) else use(keyboardList.Help)
	end)
	local helpBox = Kit.Well(scope, {
		Name = "Help",
		Size = UDim2.fromOffset(SIDE_SIZE.X, HELP_HEIGHT),
		Transparency = 0.45,
		Padding = PAD,
		-- Under the side panel; in its place while none is open.
		Position = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(MAIN_SIZE.X + GAP, if use(sidePanel) then SIDE_SIZE.Y + GAP else 0)
		end),
		Visible = scope:Computed(function(use): boolean
			return use(help) ~= ""
		end),
		Children = Kit.Label(scope, {
			Text = help,
			TextSize = Kit.TextSize.Small,
			Bold = false,
			Fit = true,
			Size = UDim2.fromScale(1, 1),
		}),
	})

	---------------------------------------------------------------------------------

	local main = Kit.Panel(scope, {
		Name = "Main",
		Size = UDim2.fromOffset(MAIN_SIZE.X, MAIN_SIZE.Y),
		Padding = PAD,
		Children = Kit.Stack(scope, {
			Size = UDim2.fromScale(1, 1),
			Gap = GAP,
			Children = {
				Kit.Label(scope, {
					Name = "Header",
					Text = "Keybinds",
					TextSize = Kit.TextSize.Heading,
					Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
					LayoutOrder = 1,
				}),
				devices,
				scope:New("Frame")({
					Name = "Keybinds",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, LIST_HEIGHT),
					LayoutOrder = 3,
					[Fusion.Children] = { keyboardList.Root, controllerList.Root },
				}),
				Kit.Label(scope, {
					Name = "Header2",
					Text = "Options",
					TextSize = Kit.TextSize.Heading,
					Size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
					LayoutOrder = 4,
				}),
				options,
			},
		}),
	})

	-- What the shell docks: the parchment, and the room the side panel and the help box
	-- take beside it.
	return scope:New("Frame")({
		Name = "Settings",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(MAIN_SIZE.X + GAP + SIDE_SIZE.X, MAIN_SIZE.Y),
		[Fusion.Children] = { main, side, helpBox },
	}) :: any
end
