--!strict
--[[
	The ability bar: one square per ability of the eaten fruits, bottom centre, above the
	tool hotbar.

	Each square shows the ability's name and key, darkens from the top while it is
	cooling down (with the seconds left), fills a bar along its foot while it charges, and
	is dimmed with the level it needs while that level is not reached. A press flashes it
	at once, before the server has answered.

	Touch devices press the abilities here: holding a square is holding its key (the aim
	is where the camera looks, onto the nearest target with Aim Assist). There the bar is
	two rows (second fruit on top) above the context buttons and the jump button
	(UI.Util.TouchLayout).
	With a gamepad on the "Legacy" controller type (Classic), the square chosen with the
	selection buttons is outlined and shows the button that uses it; on "Shortcut"
	(Advanced) every square shows its own button. Keys and buttons are the player's own
	(Hotkeys, read through InputConfig.ReadKey).

	On touch each disc follows the control layouts (ControlsController): it sits in an
	invisible slot that holds its place in the rows, and UI.Util.TouchControls moves it to
	the full-screen "Custom" layer when the player gave it a place of its own, scales it,
	and turns the touches into the key going down and up by the disc's behaviour: Hold -
	the default described above - Toggle, DoubleTap, Release or Tap, chosen by the player
	("Custom") or from what the ability on the disc does with its key ("Auto"). A disc
	whose key is held with no finger on it (Toggle) stays lit until the key is let go.

	State comes from AbilityController (cooldowns and charges reported by the server) and
	the replicated data (fruits, levels, hotkeys).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local Interface = require(ReplicatedStorage.Client.UI.Util.Interface)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local PadIcons = require(ReplicatedStorage.Client.UI.Util.PadIcons)
local TouchControls = require(ReplicatedStorage.Client.UI.Util.TouchControls)
local TouchLayout = require(ReplicatedStorage.Client.UI.Util.TouchLayout)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local peek = Fusion.peek

local SLOT_SIZE = 70
local TOUCH_SLOT_SIZE = TouchLayout.AbilitySize
local DISC = TouchLayout.Disc
local GAP = Theme.Space.XS
local GROUP_GAP = Theme.Space.L
local CHARGE_HEIGHT = 6
local PAD_ICON_SIZE = 20
-- Above the tool hotbar the engine draws at the bottom of the screen.
local BOTTOM_MARGIN = 96
-- Cooldowns shorter than this are not worth a sweep.
local MIN_COOLDOWN = 0.5
local FLASH_SECONDS = 0.15
local NO_FRUIT = FruitConfig.EmptyName
-- The seconds left of a cooldown: a red that still reads over the dark sheet.
local COOLDOWN_TEXT = Color3.fromRGB(255, 64, 64)

-- Keyboard key names as they read on a key cap.
local KEY_LABELS: { [string]: string } = {
	One = "1", Two = "2", Three = "3", Four = "4", Five = "5",
	Six = "6", Seven = "7", Eight = "8", Nine = "9", Zero = "0",
	LeftControl = "Ctrl", RightControl = "Ctrl", LeftAlt = "Alt", RightAlt = "Alt",
	LeftShift = "Shift", RightShift = "Shift", CapsLock = "Caps", Backquote = "`",
	Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]", Semicolon = ";",
	Quote = "'", Comma = ",", Period = ".", BackSlash = "\\",
}

local function keyLabel(name: any): string
	if type(name) ~= "string" or name == InputConfig.Unbound then
		return ""
	end
	local short = string.match(name, "^Button(.+)$") or string.match(name, "^DPad(.+)$")
	return KEY_LABELS[name] or short or name
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local AbilityController = Knit.GetController("AbilityController")
		local InputController = Knit.GetController("InputController")
		local hud = Knit.GetController("UIController"):GetHudState()
		local touch = UserInputService.TouchEnabled

		local slotSize = if touch then TOUCH_SLOT_SIZE else SLOT_SIZE

		local hasCharacter = scope:Value(LocalCharacter.Exists())
		table.insert(scope, LocalCharacter.Observe(function(character: Model?)
			hasCharacter:set(character ~= nil)
		end))
		local barShown = scope:Computed(function(use): boolean
			-- Touch: a menu window or one of the menu's screens takes the room of the discs
			-- (UI.Util.MenuSpace), which would otherwise show through and over it.
			if touch and use(MenuSpace.Busy) then
				return false
			end
			-- The old game had no ability bar: the legacy interface only keeps it where it is
			-- the controls themselves (touch).
			return use(hasCharacter) and use(hud.Spawned) and (touch or use(Interface.Style) ~= "Legacy")
		end)

		-- Touch: where the discs the player moved are parented, and what follows each disc.
		local layer: Frame? = if touch
			then TouchLayout.optOut(scope:New("Frame")({
				Name = "Custom",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}))
			else nil
		local controls: { [string]: TouchControls.Control } = {}

		-- Signal connections are not cleaned up by Fusion itself.
		local function own(connection: any)
			table.insert(scope, function()
				connection:Disconnect()
			end)
		end

		-- One clock for every sweep; it only ticks while something is cooling or charging.
		local clock = scope:Value(os.clock())
		local revision = scope:Value(0)
		local function busy(): boolean
			local now = os.clock()
			for fruitSlot = 1, 2 do
				for abilitySlot = 1, #InputConfig.SlotLetters do
					local state = AbilityController:GetState(InputConfig.GetAbilityAction(fruitSlot, abilitySlot))
					if state.ChargeStart or state.ReadyAt > now - 0.1 then
						return true
					end
				end
			end
			return false
		end
		local ticking: RBXScriptConnection? = nil
		local function wake()
			if ticking then
				return
			end
			ticking = RunService.RenderStepped:Connect(function()
				clock:set(os.clock())
				if not busy() then
					(ticking :: RBXScriptConnection):Disconnect()
					ticking = nil
				end
			end)
		end
		table.insert(scope, function()
			if ticking then
				ticking:Disconnect()
			end
		end)
		own(AbilityController.StateChanged:Connect(function()
			revision:set(peek(revision) + 1)
			wake()
		end))

		local flashes: { [string]: Fusion.Value<boolean> } = {}
		own(AbilityController.Pressed:Connect(function(action: string)
			local flash = flashes[action]
			if flash then
				flash:set(true)
				task.delay(FLASH_SECONDS, function()
					flash:set(false)
				end)
			end
		end))

		-- Gamepad, "Legacy" controller type: the ability the D-pad has selected.
		local function follow(signal: any, initial: any): Fusion.Value<any>
			local value = scope:Value(initial)
			own(signal:Connect(function(current: any)
				value:set(current)
			end))
			return value
		end
		-- The server ended a charge: a disc that was holding the key by itself lets go.
		own(AbilityController.ChargeEnded:Connect(function(action: string)
			local control = controls[action]
			if control then
				control.Settle()
			end
		end))
		local usingGamepad = follow(InputController.DeviceChanged, InputController:IsUsingGamepad())
		local selection = follow(InputController.SelectionChanged, InputController:GetSelectedAbility())
		local controllerType = Bind.data(scope, "Settings.ControllerType", InputConfig.ControllerTypes.Legacy)
		local hotkeys = Bind.data(scope, "Hotkeys", {})
		local levels: { [string]: Fusion.StateObject<any> } = {}
		for _, skill in { "Melee", "Defense", "Sniper", "Sword", "Haki" } do
			levels[skill] = Bind.data(scope, `Skills.{skill}.Level`, 0)
		end

		local function slot(fruitSlot: number, abilitySlot: number, fruitName: Fusion.StateObject<any>): Instance
			local action = InputConfig.GetAbilityAction(fruitSlot, abilitySlot)
			local flash = scope:Value(false)
			flashes[action] = flash
			-- Touch: the disc holds its key by itself (a "Toggle" behaviour, tapped on).
			local latched = scope:Value(false)

			local definition = scope:Computed(function(use): FruitConfig.AbilityDefinition?
				local name = use(fruitName)
				return if type(name) == "string" and name ~= NO_FRUIT then FruitConfig.GetAbility(name, abilitySlot) else nil
			end)
			local level = scope:Computed(function(use): number
				local current = use(definition)
				local skillLevel = if current then levels[current.Skill] else nil
				return if skillLevel then tonumber(use(skillLevel)) or 0 else 0
			end)
			local locked = scope:Computed(function(use): boolean
				local current = use(definition)
				return current ~= nil and use(level) < current.Requirement
			end)

			local cooldownLeft = scope:Computed(function(use): number
				use(revision)
				local state = AbilityController:GetState(action)
				if state.CooldownSeconds < MIN_COOLDOWN then
					return 0
				end
				return math.max(0, state.ReadyAt - use(clock))
			end)
			local cooldownRatio = scope:Computed(function(use): number
				use(revision)
				local state = AbilityController:GetState(action)
				return if state.CooldownSeconds > 0 then math.clamp(use(cooldownLeft) / state.CooldownSeconds, 0, 1) else 0
			end)
			-- 0-1 while charging (pulses when the full time is unknown), nil otherwise.
			local charge = scope:Computed(function(use): number?
				use(revision)
				local state = AbilityController:GetState(action)
				local start = state.ChargeStart
				if not start then
					return nil
				end
				local held = use(clock) - start
				if state.ChargeSeconds > 0 then
					return math.clamp(held / state.ChargeSeconds, 0, 1)
				end
				return 0.5 + 0.5 * math.sin(held * 6)
			end)

			local selected = scope:Computed(function(use): boolean
				return use(usingGamepad) == true
					and use(controllerType) ~= InputConfig.ControllerTypes.Shortcut
					and use(selection) == (fruitSlot - 1) * 6 + abilitySlot
			end)
			local key = scope:Computed(function(use): string
				local all = use(hotkeys)
				local entry = if type(all) == "table" then all[action] else nil
				local saved: any = if type(entry) == "table" then entry else {}
				-- Gamepad: only the Advanced layout gives an ability a button of its own.
				if use(usingGamepad) then
					return if use(controllerType) == InputConfig.ControllerTypes.Shortcut
						then keyLabel(InputConfig.ReadKey("GP", action, saved.GP))
						else ""
				end
				return keyLabel(InputConfig.ReadKey("KB", action, saved.KB))
			end)

			-- Touch slots are discs.
			local function round(): Instance?
				return if touch then scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) else nil
			end

			-- Gamepad: the picture of the button instead of its name. Advanced layout: the
			-- button of this ability inside its fruit's menu. Classic layout: abilities have
			-- no button of their own, so only the selected one shows the button that uses it.
			local padIcon = scope:Computed(function(use): string
				if use(usingGamepad) ~= true then
					return ""
				end
				local all = use(hotkeys)
				if type(all) ~= "table" then
					return ""
				end
				-- The player's own buttons, read like InputController reads them.
				local function button(device: InputConfig.Device, name: string): string
					local row = all[name]
					return InputConfig.ReadKey(device, name, if type(row) == "table" then row[device] else nil)
				end
				if use(controllerType) == InputConfig.ControllerTypes.Shortcut then
					return PadIcons.image(button("GP", action))
				elseif use(selected) then
					return PadIcons.image(button("GC", InputConfig.UseSelected))
				end
				return ""
			end)

			-- Touch: the disc's own touches go to TouchControls, which decides what they mean.
			local function pressFrom(input: InputObject, phase: "Begin" | "End")
				local control = controls[action]
				if input.UserInputType ~= Enum.UserInputType.Touch or not control then
					return
				end
				if phase == "Begin" then
					control.Down(input)
				else
					control.Up(input)
				end
			end

			local button = scope:New("TextButton")({
				Name = action,
				Text = "",
				AutoButtonColor = false,
				-- Only touch screens press abilities from here; a click must not aim at the bar.
				Active = touch,
				Selectable = false,
				LayoutOrder = abilitySlot,
				Size = UDim2.fromOffset(slotSize, slotSize),
				-- Touch: a see-through black disc, like the rest of the touch controls.
				BackgroundColor3 = if touch then DISC.Color else Theme.Colors.Background,
				BackgroundTransparency = if touch
					then scope:Computed(function(use): number
						return if use(flash) or use(latched) then DISC.PressedTransparency else DISC.Transparency
					end)
					else 0,
				BorderSizePixel = 0,
				-- A moved disc is no longer inside the bar: it follows the bar's visibility itself.
				Visible = scope:Computed(function(use): boolean
					return use(definition) ~= nil and (not touch or use(barShown))
				end),
				[Fusion.OnEvent("InputBegan")] = function(input: InputObject)
					pressFrom(input, "Begin")
				end,
				[Fusion.OnEvent("InputEnded")] = function(input: InputObject)
					pressFrom(input, "End")
				end,
				[Fusion.Children] = {
					round(),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = scope:Computed(function(use): number
							return if use(selected) or use(flash) or use(latched)
								then 2
								else if touch then 1.5 else Theme.Stroke.Thin
						end),
						Color = scope:Computed(function(use): Color3
							if touch then
								return DISC.LineColor
							elseif use(flash) then
								return Theme.Colors.Accent
							end
							return if use(selected) then Theme.Colors.Warning else Theme.Colors.Black
						end),
						Transparency = scope:Computed(function(use): number
							return if touch and not use(flash) and not use(latched) then DISC.LineTransparency else 0
						end),
					}),
					UI.Label(scope, {
						Name = "AbilityName",
						Text = scope:Computed(function(use): string
							local current = use(definition)
							return if current then current.Name else ""
						end),
						Variant = "Tiny",
						Color = scope:Computed(function(use): Color3
							if touch then
								return Theme.Colors.White
							end
							return if use(locked) then Theme.Colors.TextDim else Theme.Colors.Text
						end),
						Wrapped = true,
						Scaled = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						-- A disc has no corners to write into: the name keeps to its middle.
						Position = if touch then UDim2.fromScale(0.5, 0.5) else UDim2.fromScale(0.5, 0.55),
						Size = if touch then UDim2.fromScale(0.74, 0.5) else UDim2.new(1, -8, 0.6, 0),
						ZIndex = 2,
					}),
					UI.Label(scope, {
						Name = "Key",
						Text = key,
						Font = Numerals.Font,
						TextSize = 13,
						Color = Theme.Colors.TextMuted,
						TextXAlignment = Enum.TextXAlignment.Left,
						Position = UDim2.fromOffset(4, 2),
						Size = UDim2.new(1, -8, 0, 14),
						Visible = scope:Computed(function(use): boolean
							return not touch and use(padIcon) == ""
						end),
						ZIndex = 2,
					}),
					UI.Image(scope, {
						Name = "PadButton",
						Image = padIcon,
						Position = UDim2.fromOffset(3, 3),
						Size = UDim2.fromOffset(PAD_ICON_SIZE, PAD_ICON_SIZE),
						Visible = scope:Computed(function(use): boolean
							return not touch and use(padIcon) ~= ""
						end),
						ZIndex = 2,
					}),
					-- Cooldown: a dark sheet that shrinks from the top as time runs out. On a
					-- disc the sheet is the whole disc and a gradient hides its upper part: a
					-- shrinking rectangle would stick out of the round edge.
					scope:New("Frame")({
						Name = "Cooldown",
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = if touch
							then UDim2.fromScale(1, 1)
							else scope:Computed(function(use): UDim2
								return UDim2.fromScale(1, use(cooldownRatio))
							end),
						BackgroundColor3 = Theme.Colors.Black,
						BackgroundTransparency = 0.35,
						BorderSizePixel = 0,
						Visible = scope:Computed(function(use): boolean
							return not touch or use(cooldownRatio) > 0
						end),
						ZIndex = 3,
						[Fusion.Children] = if touch
							then {
								round(),
								scope:New("UIGradient")({
									Rotation = 90,
									Transparency = scope:Computed(function(use): NumberSequence
										local edge = math.clamp(1 - use(cooldownRatio), 0.001, 0.998)
										return NumberSequence.new({
											NumberSequenceKeypoint.new(0, 1),
											NumberSequenceKeypoint.new(edge, 1),
											NumberSequenceKeypoint.new(edge + 0.001, 0),
											NumberSequenceKeypoint.new(1, 0),
										})
									end),
								}),
							}
							else nil,
					}),
					UI.Label(scope, {
						Name = "Seconds",
						Text = scope:Computed(function(use): string
							local left = use(cooldownLeft)
							if left <= 0 then
								return ""
							end
							return if left < 10 then string.format("%.1f", left) else tostring(math.ceil(left))
						end),
						Font = Numerals.Font,
						TextSize = 22,
						Color = COOLDOWN_TEXT,
						Outline = true,
						OutlineColor = Theme.Colors.Black,
						OutlineThickness = 1,
						OutlineTransparency = 0.2,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 4,
					}),
					-- Not reached yet: dimmed, with the level it needs.
					scope:New("Frame")({
						Name = "Locked",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.Black,
						BackgroundTransparency = 0.45,
						BorderSizePixel = 0,
						Visible = locked,
						ZIndex = 5,
						[Fusion.Children] = {
							round(),
							UI.Label(scope, {
							Text = scope:Computed(function(use): string
								local current = use(definition)
								return if current then `{current.Skill}\n{current.Requirement}` else ""
							end),
								Font = Numerals.Font,
								TextSize = 13,
								Color = Theme.Colors.White,
								Size = UDim2.fromScale(1, 1),
								ZIndex = 6,
							}),
						} :: { any },
					}),
					scope:New("Frame")({
						Name = "Charge",
						-- Inside the disc, clear of its round edge.
						AnchorPoint = if touch then Vector2.new(0.5, 1) else Vector2.new(0, 1),
						Position = if touch then UDim2.fromScale(0.5, 0.86) else UDim2.fromScale(0, 1),
						Size = if touch then UDim2.new(0.56, 0, 0, CHARGE_HEIGHT) else UDim2.new(1, 0, 0, CHARGE_HEIGHT),
						BackgroundColor3 = Theme.Colors.Black,
						BorderSizePixel = 0,
						Visible = scope:Computed(function(use): boolean
							return use(charge) ~= nil
						end),
						ZIndex = 7,
						[Fusion.Children] = scope:New("Frame")({
							Name = "Fill",
							Size = scope:Computed(function(use): UDim2
								return UDim2.fromScale(use(charge) or 0, 1)
							end),
							BackgroundColor3 = scope:Computed(function(use): Color3
								return if (use(charge) or 0) >= 1 then Theme.Colors.Accent else Theme.Colors.Warning
							end),
							BorderSizePixel = 0,
							ZIndex = 8,
						}),
					}),
				},
			})
			if not layer then
				return button
			end

			-- Touch: the slot keeps the disc's place in the row; TouchControls owns the disc.
			local holder = scope:New("Frame")({
				Name = `{action}Slot`,
				BackgroundTransparency = 1,
				LayoutOrder = abilitySlot,
				Size = UDim2.fromOffset(slotSize, slotSize),
				Visible = scope:Computed(function(use): boolean
					return use(definition) ~= nil
				end),
				[Fusion.Children] = button,
			})
			controls[action] = TouchControls.attach(scope, {
				Id = action,
				Button = button,
				Holder = holder,
				Layer = layer,
				Size = slotSize,
				Begin = function()
					InputController:Fire(action, "Touch", "Begin")
				end,
				End = function()
					InputController:Fire(action, "Touch", "End")
				end,
				Latched = function(on: boolean)
					latched:set(on)
				end,
			})
			return holder
		end

		local function group(fruitSlot: number): Instance
			local fruitName = Bind.data(scope, `DevilFruits.Slot{fruitSlot}.Name`, NO_FRUIT)
			local slots: { Instance } = {}
			for abilitySlot = 1, #InputConfig.SlotLetters do
				table.insert(slots, slot(fruitSlot, abilitySlot, fruitName))
			end
			return UI.Stack(scope, {
				Name = `Fruit{fruitSlot}`,
				Direction = "Horizontal",
				Gap = GAP,
				-- On touch the rows stack upwards: the first fruit nearest the thumb.
				LayoutOrder = if touch then 3 - fruitSlot else fruitSlot,
				AutomaticSize = Enum.AutomaticSize.XY,
				Visible = scope:Computed(function(use): boolean
					local name = use(fruitName)
					return type(name) == "string" and name ~= NO_FRUIT
				end),
				Children = slots,
			})
		end

		local bar = UI.Stack(scope, {
			Name = "Bar",
			Direction = if touch then "Vertical" else "Horizontal",
			Gap = if touch then GAP else GROUP_GAP,
			HorizontalAlignment = if touch then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			AnchorPoint = if touch then Vector2.new(1, 1) else Vector2.new(0.5, 1),
			Position = if touch then TouchLayout.abilitiesPosition(scope) else UDim2.new(0.5, 0, 1, -BOTTOM_MARGIN),
			AutomaticSize = Enum.AutomaticSize.XY,
			Visible = barShown,
			Children = { group(1), group(2) },
		})
		if touch then
			TouchLayout.optOut(bar)
		end

		return UI.Screen(scope, {
			Name = "AbilityBar",
			DisplayOrder = 2,
			Children = {
				bar,
				layer,
			} :: { any },
		})
	end,
}
