--!strict
--[[
	The touch controls around the engine's jump button (layout: UI.Util.TouchLayout):

		[ Conq ][ Special ][ Obs ][ Haki ][ Shave ][ Dash ]     above the jump button
		                                    [ Lock ][ Jump ]

	- Lock: locks the camera onto the character nearest the centre of the screen, or lets
	  go (CameraLockController). Highlighted while locked; hidden when the camera lock is
	  turned off in the settings (Settings.Camera_Lock = 0).
	- Dash, Shave, Special function: touching the button arms it (highlighted); the next
	  tap on the world uses the action at that point (InputController tap mode).
	- Haki, Observation: the button toggles at once and is highlighted while the matching
	  status is on the character.
	- Conqueror: shown from Haki 500 once a stage of it is held; the button uses it at once
	  and is highlighted while the stage 3 coating is on.

	Every button is a UI.TouchButton: a small see-through black disc with a pictogram where
	the game has one, a word otherwise.

	Each context button shows once its skill level is reached (InputConfig.MobileButtons).
	Attacks are a tap on the world; the abilities are pressed on the ability bar, above
	this row. Nothing is built on devices without a touch screen.

	Control layouts (Settings.Control_Layout, ControlsController). What is described above
	is "Default": Arm for Dash, Shave and Special, a click for the others. With "Auto" the
	buttons stay where they are and each behaves by what its action is: Dash, Shave and
	Special are used at the aim cross the moment they are touched, the toggles switch on
	the touch. With "Custom" each of these seven buttons can be moved, resized and given
	another behaviour by the player (they are listed in ControlsConfig). All of it is
	UI.Util.TouchControls' work: every disc sits in an invisible slot that holds its place
	in the layout above, and is handed to TouchControls together with the full-screen
	"Custom" layer a moved disc is parented to. While the controls editor is open every
	button is shown, unlocked or not, so that all of them can be arranged.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local TouchControls = require(ReplicatedStorage.Client.UI.Util.TouchControls)
local TouchLayout = require(ReplicatedStorage.Client.UI.Util.TouchLayout)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local GAP = Theme.Space.S
local LOCK_SETTING = "Camera_Lock"
-- The camera lock button's id in ControlsConfig.Buttons (the others use their action's name).
local LOCK_ID = "Lock"

-- What each action is called on its button; an entry without action only shows.
local LABELS: { [string]: string } = {
	Conq = "Conq",
	Dash = "Dash",
	Shave = "Shave",
	Haki = "Haki",
	Observation = "Obs",
	SpFn = "Special",
}
local NO_ACTION_LABEL = "Conq"
-- The one pictogram the game has that reads on a dark disc. The others keep a word: the
-- status icons of the hakis are dark drawings and disappear on it.
local LOCK_ICON = "rbxassetid://5332501773"
local ICONS: { [string]: string } = {}

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		if not UserInputService.TouchEnabled then
			return UI.Screen(scope, { Name = "MobileContext" })
		end

		local InputController = Knit.GetController("InputController")
		local CameraLockController = Knit.GetController("CameraLockController")
		local ControlsController = Knit.GetController("ControlsController")
		local hud = Knit.GetController("UIController"):GetHudState()

		local hasCharacter = scope:Value(LocalCharacter.Exists())
		local visible = scope:Computed(function(use): boolean
			-- A menu window or one of the menu's screens takes their room (UI.Util.MenuSpace).
			return use(hasCharacter) and use(hud.Spawned) and not use(MenuSpace.Busy)
		end)

		-- The controls editor is open: every button shows, so that it can be arranged.
		local editing = scope:Value(ControlsController:IsEditing())
		local editingConnection = ControlsController.EditingChanged:Connect(function(isEditing: boolean)
			editing:set(isEditing)
		end)
		table.insert(scope, function()
			editingConnection:Disconnect()
		end)

		-- Where the discs the player moved are parented ("Custom" control layout).
		local layer = TouchLayout.optOut(scope:New("Frame")({
			Name = "Custom",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}))

		--[[
			A disc in the slot that holds its place in the default layout, made customisable
			(TouchControls) when its id is one of ControlsConfig.Buttons. Returns the slot.
		]]
		local function customisable(
			id: string?,
			size: number,
			shown: Fusion.UsedAs<boolean>,
			slotProps: { [any]: any },
			buttonProps: { [any]: any },
			callbacks: { Arm: (() -> ())?, Fire: (() -> ())? }
		): Instance
			local known = id ~= nil and ControlsConfig.Buttons[id] ~= nil
			local control: TouchControls.Control? = nil

			buttonProps.Size = UDim2.fromOffset(size, size)
			buttonProps.AnchorPoint = Vector2.new(0.5, 0.5)
			buttonProps.Position = UDim2.fromScale(0.5, 0.5)
			buttonProps.Visible = shown
			if known then
				buttonProps.OnClick = function()
					if control then
						control.Click()
					end
				end
				buttonProps.OnDown = function(input: InputObject)
					if control then
						control.Down(input)
					end
				end
				buttonProps.OnUp = function(input: InputObject)
					if control then
						control.Up(input)
					end
				end
			end
			local button = UI.TouchButton(scope, buttonProps :: any)

			slotProps.BackgroundTransparency = 1
			slotProps.Size = UDim2.fromOffset(size, size)
			slotProps.Visible = shown
			slotProps[Fusion.Children] = button
			local slot = scope:New("Frame")(slotProps)

			if known then
				control = TouchControls.attach(scope, {
					Id = id :: string,
					Button = button,
					Holder = slot,
					Layer = layer,
					Size = size,
					Arm = callbacks.Arm,
					Fire = callbacks.Fire,
				})
			end
			return slot
		end

		local tapMode: Fusion.Value<string?> = scope:Value(InputController:GetTapMode())
		local tapConnection = InputController.TapModeChanged:Connect(function(action: string?)
			tapMode:set(action)
		end)
		table.insert(scope, function()
			tapConnection:Disconnect()
		end)

		-- Toggle statuses of the current character, re-bound on every respawn.
		local statuses: { [string]: Fusion.Value<boolean> } = {}
		local characterConnections: { RBXScriptConnection } = {}
		local function bindCharacter(character: Model?)
			hasCharacter:set(character ~= nil)
			for _, connection in characterConnections do
				connection:Disconnect()
			end
			table.clear(characterConnections)

			for status, value in statuses do
				local function update()
					local current = character and character:GetAttribute(status)
					value:set(current ~= nil and current ~= false)
				end
				if character then
					table.insert(characterConnections, character:GetAttributeChangedSignal(status):Connect(update))
				end
				update()
			end
		end

		---------------------------------------------------------------------------------
		-- Camera lock.

		local locked = scope:Value(CameraLockController:GetTarget() ~= nil)
		local lockConnection = CameraLockController.Changed:Connect(function(target: BasePart?)
			locked:set(target ~= nil)
		end)
		table.insert(scope, function()
			lockConnection:Disconnect()
		end)
		local lockStrength = Bind.data(scope, `Settings.{LOCK_SETTING}`, 0)

		local toggleLock = function()
			CameraLockController:Toggle()
		end
		local lockSlot = TouchLayout.optOut(customisable(
			LOCK_ID,
			TouchLayout.SideSize,
			scope:Computed(function(use): boolean
				return use(editing) or (use(visible) and (tonumber(use(lockStrength)) or 0) > 0)
			end),
			{
				Name = "LockSlot",
				AnchorPoint = Vector2.new(1, 1),
				Position = TouchLayout.sidePosition(scope),
			},
			{
				Name = "Lock",
				Icon = LOCK_ICON,
				ActiveColor = Theme.Colors.Danger,
				Selected = locked,
				OnClick = toggleLock,
			},
			{ Fire = toggleLock }
		))

		---------------------------------------------------------------------------------
		-- Context buttons. Button1 is the rightmost: laid out right-aligned in reverse order.

		local names: { string } = {}
		for name in InputConfig.MobileButtons do
			table.insert(names, name)
		end
		table.sort(names)

		local buttons: { Instance } = {}
		for index, name in names do
			local definition = InputConfig.MobileButtons[name]
			local level = Bind.data(scope, `Skills.{definition.Skill}.Level`, 0)
			-- Some buttons also wait for something to be earned (a Conqueror's Haki stage).
			local unlock = if definition.Unlock then Bind.data(scope, definition.Unlock, 0) else nil
			local action = definition.Action

			local active: Fusion.UsedAs<boolean> = false
			if definition.Mode == "Tap" then
				active = scope:Computed(function(use): boolean
					return use(tapMode) == action
				end)
			elseif definition.Mode == "Toggle" and definition.Status then
				local status = scope:Value(false)
				statuses[definition.Status] = status
				active = status
			end

			-- The default layout: an aimed button is armed by a click, a toggle fires on one.
			local onClick: (() -> ())? = nil
			-- Uses the action at the aim point, at once (the other behaviours of an aimed button).
			local fire: (() -> ())? = nil
			if action and definition.Mode == "Tap" then
				onClick = function()
					-- Touching an armed button again disarms it.
					InputController:SetTapMode(if InputController:GetTapMode() == action then nil else action)
				end
				fire = function()
					if InputController:GetTapMode() == action then
						InputController:SetTapMode(nil)
					end
					InputController:Fire(action, "Touch")
				end
			elseif action and definition.Mode == "Toggle" then
				onClick = function()
					InputController:Fire(action, "Touch")
				end
				fire = onClick
			end

			table.insert(
				buttons,
				customisable(
					action,
					TouchLayout.ContextSize,
					scope:Computed(function(use): boolean
						if use(editing) then
							return true
						elseif not use(visible) then
							return false
						elseif unlock and (tonumber(use(unlock)) or 0) <= 0 then
							return false
						end
						return use(level) >= definition.Level
					end),
					{ Name = `{name}Slot`, LayoutOrder = -index },
					{
						Name = name,
						Icon = if action then ICONS[action] else nil,
						Text = if action then LABELS[action] or action else NO_ACTION_LABEL,
						ActiveColor = definition.ActiveColor,
						Selected = active,
						Disabled = onClick == nil,
						OnClick = onClick,
					},
					{ Arm = if definition.Mode == "Tap" then onClick else nil, Fire = fire }
				)
			)
		end

		table.insert(scope, LocalCharacter.Observe(bindCharacter))
		table.insert(scope, function()
			for _, connection in characterConnections do
				connection:Disconnect()
			end
			table.clear(characterConnections)
		end)

		return UI.Screen(scope, {
			Name = "MobileContext",
			Children = {
				lockSlot,
				TouchLayout.optOut(UI.Stack(scope, {
					Name = "ContextButtonFrame",
					Direction = "Horizontal",
					Gap = GAP,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					AnchorPoint = Vector2.new(1, 1),
					Position = TouchLayout.contextPosition(scope),
					Size = UDim2.fromOffset(#names * (TouchLayout.ContextSize + GAP), TouchLayout.ContextSize),
					Visible = scope:Computed(function(use): boolean
						return use(visible) or use(editing)
					end),
					Children = buttons,
				})),
				layer,
			},
		})
	end,
}
