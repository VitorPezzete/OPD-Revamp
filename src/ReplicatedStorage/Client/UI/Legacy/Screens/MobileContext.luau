--!strict
--[[
	The touch controls around the engine's jump button (legacy MobileContext), placed like
	the rework's (UI.Util.TouchLayout) so that they fit the touch ability bar, which is the
	rework's in this interface too (the old game had none):

		[ Conq ][ Special ][ Obs ][ Haki ][ Shave ][ Dash ]     above the jump button
		                                    [ Lock ][ Jump ]

	- Lock: locks the camera onto the character nearest the centre of the screen, or lets
	  go (CameraLockController). Tinted while locked; hidden when the camera lock is turned
	  off in the settings (Settings.Camera_Lock = 0). It stands for the spare round button
	  of the old gui ("Button"), which no legacy script ever used.
	- Dash, Shave, Special function: touching the button arms it (tinted); the next tap on
	  the world uses the action at that point (InputController tap mode). Touching an armed
	  button again disarms it.
	- Haki, Observation: the button toggles at once and is tinted while the matching
	  status is on the character. The legacy tint was a local flag flipped on every
	  touch, so it lied whenever the server refused the toggle or the haki ran out.
	- Conqueror: shown from Haki 500 once a stage of it is held; the button uses it at once
	  and is tinted while the stage 3 coating is on. (The legacy button showed from Haki 600
	  and did nothing: no script ever handled it.)

	Each context button shows once its skill level is reached (InputConfig.MobileButtons),
	and only while there is a spawned character. Attacks are a tap on the world; the
	abilities are pressed on the ability bar, above this row. Nothing shows on devices
	without a touch screen.

	The buttons are the old game's round ones (the same disc picture), built in code, with
	their names written on them in the legacy text style (the old ActionTitle was left
	empty: six identical discs). They were drawn 25 pixels wide in a corner of the screen,
	under the jump button; here each one takes the size and the place the touch layout
	gives it.

	Control layouts (Settings.Control_Layout, ControlsController). What is described above
	is "Default": Arm for Dash, Shave and Special, a click for the others. With "Auto" the
	buttons stay where they are and each behaves by what its action is; with "Custom" each
	of these seven buttons can be moved, resized and given another behaviour by the player
	(ControlsConfig). All of it is UI.Util.TouchControls' work: every button sits in an
	invisible slot that holds its place in the layout above, and is handed to TouchControls
	together with the full-screen "Custom" layer a moved button is parented to. While the
	controls editor is open every button is shown, unlocked or not, so that all of them can
	be arranged.

	Legacy: one LocalScript per button, each waiting in a loop for the data folder.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MenuSpace = require(ReplicatedStorage.Client.UI.Util.MenuSpace)
local TouchControls = require(ReplicatedStorage.Client.UI.Util.TouchControls)
local TouchLayout = require(ReplicatedStorage.Client.UI.Util.TouchLayout)

type Scope = Fusion.Scope<typeof(Fusion)>

local GAP = TouchLayout.Gap
local IDLE_COLOR = Color3.new(1, 1, 1)
local LOCK_COLOR = Color3.new(1, 0.25, 0.25)
local LOCK_SETTING = "Camera_Lock"
-- The camera lock button's id in ControlsConfig.Buttons (the others use their action's name).
local LOCK_ID = "Lock"
local LOCK_ICON = "rbxassetid://5332501773"
-- The round button of the old touch controls.
local DISC = "rbxassetid://97166444"

-- What each action is called on its button.
local LABELS: { [string]: string } = {
	Conq = "Conq",
	Dash = "Dash",
	Shave = "Shave",
	Haki = "Haki",
	Observation = "Obs",
	SpFn = "Special",
}
local NO_ACTION_LABEL = "Conq"

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

--[[
	One of the old round buttons: the disc, the picture holder in its middle and its name
	across it. Sized and placed by the slot it is put in.
]]
local function disc(scope: Scope, name: string, title: string?, icon: string?, dimmed: boolean): ImageButton
	return scope:New("ImageButton")({
		Name = name,
		BackgroundTransparency = 1,
		Image = DISC,
		[Fusion.Children] = {
			Kit.Image(scope, {
				Name = "ActionIcon",
				Image = icon or "",
				Position = UDim2.fromScale(0.175, 0.175),
				Size = UDim2.fromScale(0.65, 0.65),
			}),
			if title
				then Kit.Label(scope, {
					Name = "ActionTitle",
					Text = title,
					TextSize = Kit.TextSize.Small,
					Fit = true,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -Kit.Space.S, 1, -Kit.Space.S),
					ZIndex = 2,
					-- A button that does nothing reads as such.
					Transparency = if dimmed then 0.5 else nil,
				})
				else nil,
		} :: { any },
	}) :: any
end

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		-- Nothing to draw without a touch screen (the old gui's two empty ContextActions
		-- holders are not built either: nothing was ever put in them).
		if not UserInputService.TouchEnabled then
			return Kit.Screen(scope, { Name = "MobileContext" })
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

		-- Where the buttons the player moved are parented ("Custom" control layout).
		local layer = TouchLayout.optOut(scope:New("Frame")({
			Name = "Custom",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			-- Over the buttons still in their place.
			ZIndex = 2,
		}))

		--[[
			Puts a button of the layout in the slot that holds its place in the default
			layout, and makes it customisable (TouchControls) when its id is one of
			ControlsConfig.Buttons. Returns the slot, for the caller to parent.
		]]
		local function customisable(
			button: GuiButton,
			id: string?,
			size: number,
			shown: Fusion.UsedAs<boolean>,
			color: Fusion.UsedAs<Color3>,
			slotProps: { [any]: any },
			callbacks: { Click: (() -> ())?, Arm: (() -> ())?, Fire: (() -> ())? }
		): Frame
			local known = id ~= nil and ControlsConfig.Buttons[id] ~= nil
			local control: TouchControls.Control? = nil

			slotProps.BackgroundTransparency = 1
			slotProps.Size = UDim2.fromOffset(size, size)
			slotProps.Visible = shown
			local slot = scope:New("Frame")(slotProps) :: any

			button.Size = UDim2.fromOffset(size, size)
			button.AnchorPoint = Vector2.new(0.5, 0.5)
			button.Position = UDim2.fromScale(0.5, 0.5)
			-- The gamepad's selection has nothing to do on the touch controls.
			button.Selectable = false
			button.Active = callbacks.Click ~= nil
			button.Parent = slot
			Bind.props(scope, button, {
				Visible = shown,
				ImageColor3 = color,
			})

			if known then
				-- The touches go to TouchControls, which decides what they mean.
				control = TouchControls.attach(scope :: any, {
					Id = id :: string,
					Button = button,
					Holder = slot,
					Layer = layer,
					Size = size,
					Arm = callbacks.Arm,
					Fire = callbacks.Fire,
				})
				Bind.connect(scope, button.InputBegan, function(input: InputObject)
					if control and isPress(input) then
						control.Down(input)
					end
				end)
				Bind.connect(scope, button.InputEnded, function(input: InputObject)
					if control and isPress(input) then
						control.Up(input)
					end
				end)
				Bind.click(scope, button, function()
					if control then
						control.Click()
					end
				end)
			elseif callbacks.Click then
				Bind.click(scope, button, callbacks.Click)
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
		-- Context buttons. Button1 is the rightmost: laid out right-aligned in reverse order.

		local names: { string } = {}
		for name in InputConfig.MobileButtons do
			table.insert(names, name)
		end
		table.sort(names)

		-- The row above the jump button. Placed from it: not ScreenScale's to move.
		local frame = TouchLayout.optOut(Kit.Stack(scope, {
			Name = "ContextButtonFrame",
			Direction = "Horizontal",
			Gap = GAP,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(#names * (TouchLayout.ContextSize + GAP), TouchLayout.ContextSize),
			Position = TouchLayout.contextPosition(scope),
			Visible = scope:Computed(function(use): boolean
				return use(visible) or use(editing)
			end),
		}))

		for index, name in names do
			local definition = InputConfig.MobileButtons[name]

			local level = Bind.data(scope, `Skills.{definition.Skill}.Level`, 0)
			-- Some buttons also wait for something to be earned (a Conqueror's Haki stage).
			local unlock = if definition.Unlock then Bind.data(scope, definition.Unlock, 0) else nil
			local action = definition.Action
			local activeColor = definition.ActiveColor or IDLE_COLOR

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

			local button = disc(
				scope,
				name,
				if action then LABELS[action] or action else NO_ACTION_LABEL,
				nil,
				onClick == nil
			)

			local slot = customisable(
				button,
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
					return (tonumber(use(level)) or 0) >= definition.Level
				end),
				scope:Computed(function(use): Color3
					return if use(active) then activeColor else IDLE_COLOR
				end),
				{ Name = `{name}Slot`, LayoutOrder = -index },
				{ Click = onClick, Arm = if definition.Mode == "Tap" then onClick else nil, Fire = fire }
			)
			slot.Parent = frame
		end

		---------------------------------------------------------------------------------
		-- Camera lock: the spare button of the old gui, with a picture instead of a name.

		local lockSlot: Frame
		do
			local spare = disc(scope, "Button", nil, LOCK_ICON, false)
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
			lockSlot = customisable(
				spare,
				LOCK_ID,
				TouchLayout.SideSize,
				scope:Computed(function(use): boolean
					return use(editing) or (use(visible) and (tonumber(use(lockStrength)) or 0) > 0)
				end),
				scope:Computed(function(use): Color3
					return if use(locked) then LOCK_COLOR else IDLE_COLOR
				end),
				{
					Name = "LockSlot",
					AnchorPoint = Vector2.new(1, 1),
					Position = TouchLayout.sidePosition(scope),
				},
				{ Click = toggleLock, Fire = toggleLock }
			)
			-- Placed from the jump button, like the row: not ScreenScale's to move.
			TouchLayout.optOut(lockSlot)
		end

		table.insert(scope, LocalCharacter.Observe(bindCharacter))
		table.insert(scope, function()
			for _, connection in characterConnections do
				connection:Disconnect()
			end
			table.clear(characterConnections)
		end)

		return Kit.Screen(scope, {
			Name = "MobileContext",
			Children = { frame, lockSlot, layer },
		})
	end,
}
