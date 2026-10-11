--!strict
--[[
	The one place where keys, gamepad buttons and the mobile context buttons become
	actions. It reads the player's Hotkeys data (re-mapping live when it changes) and
	tells whoever subscribed that an action began or ended; it knows nothing about what
	an action does.

		local disconnect = InputController:OnAction("Dash", function(phase, source)
			-- phase: "Begin" | "End", source: "Keyboard" | "Gamepad" | "Touch"
		end)
		InputController:GetAimPosition()     -- world point under the cursor / the tap

	Actions: Dash, Shave, Haki, Observation, Conq, Emotes, SpFn, Unassigned1-3, the twelve
	ability slots DF1A..DF2F and, from a gamepad, Attack, CameraLock, ToolNext and
	ToolPrevious (see InputConfig). Haki, Observation and Conq are wired here because they
	are one call each; everything else is subscribed by its owner (the emote wheel belongs
	to EmoteController, which reads its own key; the tools to ToolCycleController).

	Keyboard: every action has its own key (Hotkeys.<Action>.KB).

	Gamepad. Every button of every action is the player's (Settings > Keybinds >
	Controller), one column of the Hotkeys rows per layout, and the two layouts are
	Settings.ControllerType:
	- "Legacy", the Classic layout, with nothing to hold (column GC): one button per basic
	  action, two buttons walk through the ability slots (SelectNext / SelectPrevious, 1-6
	  or 1-12 with a second fruit) and a third (DPadFn) uses the selected one.
	- "Shortcut", the Advanced layout (column GP): nothing is selected, every ability has
	  its own chord. Holding Menu1 / Menu2 (L2 / L1 by default) turns the buttons into that
	  fruit's six abilities (A, X, B, Y, R1, R2) for as long as it is held, and while it is
	  held those buttons do nothing else. With no menu held the basic actions have their
	  own buttons. The legacy game hid this behind two more buttons that switched between
	  a "Default" and an "Ability" mode; the layout is always in Ability mode here.

	One mechanism for the whole pad: ContextActionService, above the engine's own
	bindings (onPad). Three buttons are the engine's besides A, which jumps: L1 / R1 walk
	through the backpack and the right stick button changes the camera's zoom. The engine
	takes them first, and UserInputService then reports them as already used
	(gameProcessed): that is why the chords were once dead, why the special attack did
	nothing on R1 and why the camera lock could not be switched on with the right stick
	button. Heard from up here, every button reaches its action whatever the engine does
	with it afterwards. What happens to the press next:
	- a fruit menu button, and an ability of the held menu, are taken (sunk): nothing
	  else sees them, as before;
	- a basic action on one of the engine's three buttons is taken too, or the engine
	  would also walk the hotbar or zoom the camera on the same press;
	- a basic action on any other button is passed on after it was used, exactly as when
	  these were read from UserInputService: scripts that listen to the same button
	  themselves (the swing of a fruit's sword on the right trigger, the fishing game on
	  the D-pad) still get it, not marked as used;
	- a button with nothing bound is passed on untouched and keeps its normal job.
	While the interface holds the gamepad's selection (GuiService.SelectedObject) or the
	Roblox menu is open, the basic actions do nothing: the buttons belong to the interface.

	Capture (CapturePadButton, for the settings tab's "press a button"): the next press of
	any gamepad button is taken - it reaches neither the game nor the interface - and
	handed to the caller, together with its release. View / Select, which can never be
	bound, cancels; so does a few seconds without a press. While it lasts the interface's
	selection is put aside, or the engine would spend the D-pad, A and B on it; IsCapturing
	tells NavigationController not to take that B for "close the window".

	Touch: the context buttons call Fire directly (toggles) or arm a tap mode (Dash,
	Shave, SpFn): the next tap on the world fires the action aimed at that point. A tap
	on the world with nothing armed is an "Attack" aimed there (a drag turns the camera
	and is not a tap); the ability bar fires the ability actions itself.

	"Attack" (the basic weapon swing) also comes from a gamepad button (the right trigger
	by default); the mouse button stays with CombatController. "CameraLock" is a gamepad
	action too (the right stick button by default).

	Aim (GetAimPosition, through GetAimPoint): under the cursor with a mouse, the centre
	of the screen with a gamepad, a point above the character's head on a touch screen
	(the cross of AimReticle). Without a cursor, the "Custom" control layout moves that
	point by the player's aim offset (ControlsController:GetAimOffset); everything that
	reads the aim goes through GetAimPoint, so it all agrees with the cross. Without a
	cursor, and
	with Settings.Aim_Assist on, the aim lands on the character nearest to that point
	(Client.Util.AimAssist). A camera lock (CameraLockController) overrides both: the
	aim is its target.

	Suspended (SetSuspended, used by the controls editor): no action begins - keys, gamepad
	buttons, taps on the world and Fire are ignored, whatever was held is let go and
	nothing can be armed. An "End" still goes through, so nothing stays held.

	Device: "KeyboardMouse", "Gamepad" or "Touch", from the last input; reported to the
	server (InputService), which leads projectiles for the last two.

	Replaces PressQ_Haki, PressR_Observationv2 (its key handling), PressE_Dash,
	PressCTRL_Shave, PressALT_Emote, PressDPAD, ControllerBinds and CoreModule, which
	each waited on the data folder in a loop and re-bound ContextActionService on their own.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local AimAssist = require(ReplicatedStorage.Client.Util.AimAssist)
local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)

export type Phase = "Begin" | "End"
export type Source = "Keyboard" | "Gamepad" | "Touch"
export type ControllerMode = "Default" | "Ability"
export type ActionCallback = (phase: Phase, source: Source) -> ()
export type DeviceKind = "KeyboardMouse" | "Gamepad" | "Touch"

type Press = { Action: string, Source: Source }

local NO_FRUIT = "None"
local TAP_ARM_DELAY = 0.1
local ATTACK_ACTION = "Attack"
local PAD_ACTION = "GamepadActions"
local CAPTURE_ACTION = "GamepadCapture"
-- Capture: seconds it waits for a press, seconds it waits for that press to be let go,
-- and how long after it ended a press still counts as its own (IsCapturing).
local CAPTURE_SECONDS = 6
local CAPTURE_RELEASE_SECONDS = 1
local CAPTURE_GRACE = 0.25
-- Buttons the engine acts on by itself (hotbar, camera zoom): a basic action bound to
-- one of them takes the press away from the engine (see the header).
local ENGINE_BUTTONS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.ButtonL1] = true,
	[Enum.KeyCode.ButtonR1] = true,
	[Enum.KeyCode.ButtonR3] = true,
}
-- The button that cancels a capture: it can never be bound (the interface's).
local CAPTURE_CANCEL = Enum.KeyCode.ButtonSelect
-- Pixels the moved aim point keeps from the edges of the viewport.
local AIM_MARGIN = 8

local InputController = Knit.CreateController({
	Name = "InputController",
})

-- (usingGamepad: boolean) when the last used device changes between gamepad and anything else.
InputController.DeviceChanged = Signal.new() :: Signal.Signal<boolean>
-- (kind: DeviceKind) when the kind of device last used changes.
InputController.DeviceKindChanged = Signal.new() :: Signal.Signal<DeviceKind>
-- (mode: ControllerMode) "Shortcut" controller type only.
InputController.ControllerModeChanged = Signal.new() :: Signal.Signal<ControllerMode>
-- (fruitSlot: number?) the fruit menu currently held on the gamepad, nil when none.
InputController.MenuChanged = Signal.new() :: Signal.Signal<number?>
-- (index: number) ability selected with the D-pad, 1-12 ("Legacy" controller type).
InputController.SelectionChanged = Signal.new() :: Signal.Signal<number>
-- (action: string?) the action armed for the next tap, nil when none.
InputController.TapModeChanged = Signal.new() :: Signal.Signal<string?>

local DataController
local SettingsController
local CameraLockController
local ControlsController

local localPlayer = Players.LocalPlayer
local listeners: { [string]: { ActionCallback } } = {}

local keyboardBindings: { [Enum.KeyCode]: { string } } = {}
-- Basic actions on the gamepad, for the current controller type.
local gamepadBindings: { [Enum.KeyCode]: { string } } = {}
-- "Shortcut": fruit slot -> button -> ability action, while that fruit's menu is held.
local menuBindings: { [number]: { [Enum.KeyCode]: string } } = { {}, {} }
local menuKeys: { [Enum.KeyCode]: number } = {}

type Capture = {
	Callback: (keyName: string?) -> (),
	-- What the interface had selected when the capture began, put back when it ends.
	Restore: GuiObject?,
	-- The button taken, once one was pressed: the capture then only waits for its release.
	Key: Enum.KeyCode?,
	Reported: boolean,
}
local capture: Capture? = nil
local captureEndedAt = -math.huge

local controllerType: string = InputConfig.ControllerTypes.Legacy
local controllerMode: ControllerMode = "Default"
local heldMenus: { [number]: boolean } = {}
local activeMenu: number? = nil
local selectedAbility = 1
local usingGamepad = false
-- A phone or tablet starts as touch; anything with a keyboard starts as a computer.
local deviceKind: DeviceKind = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then "Touch"
	else "KeyboardMouse"
local tapMode: string? = nil
local tapArmedAt = 0
-- Screen point of the tap being dispatched, so its subscribers aim where it landed.
local tapPoint: Vector3? = nil
-- What each held key started, so the matching End always reaches the same action.
local held: { [Enum.KeyCode]: { Press } } = {}
-- Gamepad buttons whose press was taken from everyone else: their release is taken too.
local sunk: { [Enum.KeyCode]: boolean } = {}
-- While true no action begins (the controls editor is open).
local suspended = false

local function toKeyCode(name: any): Enum.KeyCode?
	if type(name) ~= "string" or name == InputConfig.Unbound then
		return nil
	end
	local ok, keyCode = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	-- "Unknown" is what every non-key input reports, so it can never be a binding.
	return if ok and keyCode ~= Enum.KeyCode.Unknown then keyCode else nil
end

local function addBinding(into: { [Enum.KeyCode]: { string } }, keyCode: Enum.KeyCode?, action: string)
	if not keyCode then
		return
	end
	local actions = into[keyCode]
	if not actions then
		actions = {}
		into[keyCode] = actions
	end
	table.insert(actions, action)
end

local function dispatch(action: string, phase: Phase, source: Source)
	local callbacks = listeners[action]
	if not callbacks then
		return
	end
	for _, callback in table.clone(callbacks) do
		task.spawn(callback, phase, source)
	end
end

local function setTapMode(action: string?)
	if tapMode ~= action then
		tapMode = action
		tapArmedAt = os.clock()
		InputController.TapModeChanged:Fire(action)
	end
end

local function press(keyCode: Enum.KeyCode, actions: { string }, source: Source)
	if suspended then
		return
	end
	local presses = held[keyCode]
	if not presses then
		presses = {}
		held[keyCode] = presses
	end
	for _, action in actions do
		-- Using an action by key cancels its pending tap (legacy behaviour).
		if tapMode == action then
			setTapMode(nil)
		end
		table.insert(presses, { Action = action, Source = source })
		dispatch(action, "Begin", source)
	end
end

local function release(keyCode: Enum.KeyCode)
	local presses = held[keyCode]
	if presses then
		held[keyCode] = nil
		for _, entry in presses do
			dispatch(entry.Action, "End", entry.Source)
		end
	end
end

local function releaseAll()
	for keyCode in table.clone(held) do
		release(keyCode)
	end
end

local function setActiveMenu(menu: number?)
	if activeMenu ~= menu then
		activeMenu = menu
		InputController.MenuChanged:Fire(menu)
	end
end

local function setControllerMode(mode: ControllerMode)
	table.clear(heldMenus)
	setActiveMenu(nil)
	if controllerMode ~= mode then
		controllerMode = mode
		InputController.ControllerModeChanged:Fire(mode)
	end
end

local function getSelectionCount(): number
	local secondFruit = DataController:Get("DevilFruits.Slot2.Name")
	return if secondFruit ~= nil and secondFruit ~= NO_FRUIT then 12 else 6
end

local function setSelection(index: number)
	local count = getSelectionCount()
	local wrapped = (index - 1) % count + 1
	if selectedAbility ~= wrapped then
		selectedAbility = wrapped
		InputController.SelectionChanged:Fire(wrapped)
	end
end

local function rebuildBindings()
	table.clear(keyboardBindings)
	table.clear(gamepadBindings)
	table.clear(menuBindings[1])
	table.clear(menuBindings[2])
	table.clear(menuKeys)
	-- The menu buttons may be other ones now: no menu is held any more.
	table.clear(heldMenus)
	setActiveMenu(nil)

	local hotkeys = DataController:Get("Hotkeys")
	if type(hotkeys) ~= "table" then
		return
	end

	-- The key in force: what is saved, or the default where the profile holds nothing valid.
	local function getKey(action: string, device: InputConfig.Device): Enum.KeyCode?
		local row = hotkeys[action]
		return toKeyCode(InputConfig.ReadKey(device, action, if type(row) == "table" then row[device] else nil))
	end

	for action in InputConfig.Contexts.KB do
		-- An action that is switched off keeps its key in the profile and gets no binding.
		if InputConfig.IsEnabled(action) then
			addBinding(keyboardBindings, getKey(action, "KB"), action)
		end
	end

	local savedType = DataController:Get("Settings.ControllerType")
	local previousType = controllerType
	controllerType = if savedType == InputConfig.ControllerTypes.Shortcut
		then InputConfig.ControllerTypes.Shortcut
		else InputConfig.ControllerTypes.Legacy
	if controllerType ~= previousType then
		-- The Advanced layout has no modes: it is always the one with the fruit menus.
		setControllerMode(if controllerType == InputConfig.ControllerTypes.Shortcut then "Ability" else "Default")
	end

	-- The column of the layout in use: its menus and chords (Advanced only), its basic actions.
	local device = InputConfig.PadDevice(controllerType)
	for _, entry in InputConfig.PadActions[device] do
		local keyCode = getKey(entry.Action, device)
		if keyCode then
			if entry.Menu and entry.Fruit then
				menuKeys[keyCode] = entry.Fruit
			elseif entry.Fruit then
				menuBindings[entry.Fruit][keyCode] = entry.Action
			else
				addBinding(gamepadBindings, keyCode, entry.Action)
			end
		end
	end
end

-- Whether the gamepad's buttons belong to the interface right now.
local function interfaceHasPad(): boolean
	return GuiService.SelectedObject ~= nil or GuiService.MenuIsOpen
end

-- A basic button went down. The Classic layout's selection is handled here; everything
-- else is an action like any other.
local function pressPad(keyCode: Enum.KeyCode, actions: { string })
	local direct: { string } = {}
	for _, action in actions do
		if action == InputConfig.SelectNext then
			setSelection(selectedAbility + 1)
		elseif action == InputConfig.SelectPrevious then
			setSelection(selectedAbility - 1)
		elseif action == InputConfig.UseSelected then
			-- A fruit dropped since the last selection can leave the index out of range.
			setSelection(selectedAbility)
			table.insert(direct, InputConfig.GetAbilityAction(InputConfig.SplitAbilityIndex(selectedAbility)))
		else
			table.insert(direct, action)
		end
	end
	if #direct > 0 then
		press(keyCode, direct, "Gamepad")
	end
end

--[[
	Every gamepad button, heard through ContextActionService above the engine's bindings
	(see the header). A menu button opens its fruit's menu for as long as it is held; a
	button with an ability in the held menu presses that ability; a button with a basic
	action presses it, unless the interface has the pad. The first two are sunk, and so
	is a basic action on a button the engine would act on as well; everything else is
	passed on, so a button with nothing bound keeps its normal job.
]]
local function onPad(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	local keyCode = input.KeyCode
	local began = state == Enum.UserInputState.Begin
	local ended = state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel

	local menu = menuKeys[keyCode]
	if menu then
		if began then
			heldMenus[menu] = true
			setActiveMenu(menu)
		elseif ended and heldMenus[menu] then
			heldMenus[menu] = nil
			-- Releasing one menu while the other is still held gives the buttons back to it.
			local other = 3 - menu
			setActiveMenu(if heldMenus[other] then other else nil)
		end
		return Enum.ContextActionResult.Sink
	end

	if ended then
		-- Whatever this button pressed is let go, even after its menu or with the interface open.
		local taken = sunk[keyCode]
		sunk[keyCode] = nil
		if held[keyCode] then
			release(keyCode)
		end
		return if taken then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	elseif not began then
		return Enum.ContextActionResult.Pass
	end

	-- A release that never came (the window lost focus) must not mark this press.
	sunk[keyCode] = nil
	local active = activeMenu
	local ability = if active then menuBindings[active][keyCode] else nil
	if ability then
		sunk[keyCode] = true
		press(keyCode, { ability }, "Gamepad")
		return Enum.ContextActionResult.Sink
	end

	local actions = gamepadBindings[keyCode]
	if not actions or suspended or interfaceHasPad() then
		return Enum.ContextActionResult.Pass
	end
	pressPad(keyCode, actions)
	if ENGINE_BUTTONS[keyCode] then
		sunk[keyCode] = true
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function kindOf(inputType: Enum.UserInputType): DeviceKind?
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
		return "Gamepad"
	elseif
		inputType == Enum.UserInputType.Keyboard
		or inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.MouseButton2
		or inputType == Enum.UserInputType.MouseMovement
		or inputType == Enum.UserInputType.MouseWheel
	then
		return "KeyboardMouse"
	end
	return nil
end

local function onLastInputType(inputType: Enum.UserInputType)
	local kind = kindOf(inputType)
	if kind and kind ~= deviceKind then
		deviceKind = kind
		InputController.DeviceKindChanged:Fire(kind)
		Knit.GetService("InputService").Device:Fire(kind)
	end
end

local function setUsingGamepad(value: boolean)
	if usingGamepad ~= value then
		usingGamepad = value
		InputController.DeviceChanged:Fire(value)
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.Gamepad1 then
		setUsingGamepad(true)
	elseif inputType ~= Enum.UserInputType.Focus and inputType ~= Enum.UserInputType.None then
		setUsingGamepad(false)
	end

	-- The gamepad's buttons are onPad's (ContextActionService): only the keyboard is read here.
	if gameProcessed or inputType ~= Enum.UserInputType.Keyboard then
		return
	end
	local actions = keyboardBindings[input.KeyCode]
	if actions then
		press(input.KeyCode, actions, "Keyboard")
	end
end

local function onInputEnded(input: InputObject)
	release(input.KeyCode)

	local menu = menuKeys[input.KeyCode]
	if menu and heldMenus[menu] then
		heldMenus[menu] = nil
		-- Releasing one menu while the other is still held gives the buttons back to it.
		local other = 3 - menu
		setActiveMenu(if heldMenus[other] then other else nil)
	end
end

local function onTouchTap(positions: { Vector2 }, gameProcessed: boolean)
	local action = tapMode
	local position = positions[1]
	if gameProcessed or not position or suspended then
		return
	end
	-- Nothing armed: the tap is a swing of the held weapon, aimed where it landed.
	if not action then
		tapPoint = Vector3.new(position.X, position.Y, 0)
		dispatch(ATTACK_ACTION, "Begin", "Touch")
		dispatch(ATTACK_ACTION, "End", "Touch")
		tapPoint = nil
		return
	end
	-- The touch that armed the action must not also be the one that uses it.
	if os.clock() - tapArmedAt < TAP_ARM_DELAY then
		return
	end

	setTapMode(nil)
	-- Subscribers run synchronously up to their first yield: they read the aim from here.
	tapPoint = Vector3.new(position.X, position.Y, 0)
	dispatch(action, "Begin", "Touch")
	dispatch(action, "End", "Touch")
	tapPoint = nil
end

---------------------------------------------------------------------------------
-- Capture of one gamepad press (see the header).

-- Every button a capture listens to: the ones that can be bound, and the one that cancels.
local function captureButtons(): { Enum.KeyCode }
	local buttons: { Enum.KeyCode } = { CAPTURE_CANCEL }
	for keyName in InputConfig.Keys.GP do
		local keyCode = toKeyCode(keyName)
		if keyCode then
			table.insert(buttons, keyCode)
		end
	end
	return buttons
end

local function reportCapture(state: Capture, keyName: string?)
	if not state.Reported then
		state.Reported = true
		task.spawn(state.Callback, keyName)
	end
end

local function endCapture(state: Capture)
	if capture ~= state then
		return
	end
	capture = nil
	captureEndedAt = os.clock()
	ContextActionService:UnbindAction(CAPTURE_ACTION)

	local restore = state.Restore
	if restore and usingGamepad and GuiService.SelectedObject == nil and restore:IsDescendantOf(game) then
		GuiService.SelectedObject = restore
	end
end

local function onCapture(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	local current = capture
	if not current then
		return Enum.ContextActionResult.Pass
	end

	local taken = current.Key
	if taken then
		-- The press is taken: its release ends the capture, and nothing else gets through.
		if input.KeyCode == taken and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) then
			-- Deferred: the binding is not taken away from inside its own call.
			task.defer(endCapture, current)
		end
		return Enum.ContextActionResult.Sink
	end
	if state ~= Enum.UserInputState.Begin then
		-- The release of whatever was down when the capture began is nobody's business here.
		return Enum.ContextActionResult.Pass
	end

	current.Key = input.KeyCode
	local keyName = input.KeyCode.Name
	reportCapture(current, if InputConfig.Keys.GP[keyName] then keyName else nil)
	-- A release that never comes (the pad was unplugged) must not leave the pad captured.
	task.delay(CAPTURE_RELEASE_SECONDS, endCapture, current)
	return Enum.ContextActionResult.Sink
end

--[[
	Takes the next press of a gamepad button: `callback(keyName)` gets the name of the
	button ("ButtonB", "DPadLeft", ...), or nil when the capture was cancelled with View /
	Select or nothing was pressed in time. It is called once. The returned function gives
	the capture up without calling back. One capture at a time: a new one cancels the old.
]]
function InputController:CapturePadButton(callback: (keyName: string?) -> ()): () -> ()
	local previous = capture
	if previous then
		reportCapture(previous, nil)
		endCapture(previous)
	end

	local state: Capture = {
		Callback = callback,
		Restore = GuiService.SelectedObject,
		Key = nil,
		Reported = false,
	}
	capture = state
	-- With something selected the engine would spend the D-pad, A and B on the interface.
	GuiService.SelectedObject = nil
	ContextActionService:BindActionAtPriority(
		CAPTURE_ACTION,
		onCapture,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		table.unpack(captureButtons())
	)
	task.delay(CAPTURE_SECONDS, function()
		if capture == state and not state.Key then
			reportCapture(state, nil)
			endCapture(state)
		end
	end)

	return function()
		state.Reported = true
		endCapture(state)
	end
end

-- Whether a gamepad press is being captured, or was a moment ago: that press is not a
-- "back" or a "select" for anybody else.
function InputController:IsCapturing(): boolean
	return capture ~= nil or os.clock() - captureEndedAt < CAPTURE_GRACE
end

-- Subscribes to an action. Returns a function that removes the subscription.
function InputController:OnAction(actionName: string, callback: ActionCallback): () -> ()
	local callbacks = listeners[actionName]
	if not callbacks then
		callbacks = {}
		listeners[actionName] = callbacks
	end
	table.insert(callbacks, callback)

	return function()
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

-- Fires an action as if its key had been used (on-screen buttons). Phase defaults to a full press.
function InputController:Fire(actionName: string, source: Source?, phase: Phase?)
	local from: Source = source or "Touch"
	-- Suspended: nothing begins. An End alone still passes, for whatever began before.
	if suspended and phase ~= "End" then
		return
	end
	if phase then
		dispatch(actionName, phase, from)
	else
		dispatch(actionName, "Begin", from)
		dispatch(actionName, "End", from)
	end
end

-- Arms `actionName` for the next tap on the world (nil disarms).
function InputController:SetTapMode(actionName: string?)
	if suspended and actionName ~= nil then
		return
	end
	setTapMode(actionName)
end

--[[
	Stops (true) or resumes (false) turning input into actions. Suspending lets go of
	every held key and disarms the pending tap, so nothing is left running.
]]
function InputController:SetSuspended(value: boolean)
	if suspended == value then
		return
	end
	if value then
		releaseAll()
		setTapMode(nil)
	end
	suspended = value
end

function InputController:IsSuspended(): boolean
	return suspended
end

function InputController:GetTapMode(): string?
	return tapMode
end

function InputController:IsUsingGamepad(): boolean
	return usingGamepad
end

function InputController:GetDeviceKind(): DeviceKind
	return deviceKind
end

-- Whether the aim is helped right now: no cursor (gamepad / touch) and the setting on.
function InputController:IsAimAssisted(): boolean
	return deviceKind ~= "KeyboardMouse" and SettingsController:Get("Aim_Assist") ~= false
end

-- Where the cursor a gamepad player sees is, nil when there is none to go by. The engine
-- keeps drawing the pointer while a gamepad is used - parked wherever it was left, or moved
-- by the console - and that pointer is what the player takes for the aim: reading its real
-- position is right on every platform, where guessing "the centre of the screen" is not.
local function gamepadCursor(camera: Camera): Vector2?
	if not UserInputService.MouseIconEnabled then
		return nil
	end
	local cursor = UserInputService:GetMouseLocation()
	local size = camera.ViewportSize
	-- (0, 0) is what a device without a pointer reports.
	if cursor.X <= 0 and cursor.Y <= 0 then
		return nil
	end
	if cursor.X > size.X or cursor.Y > size.Y then
		return nil
	end
	return cursor
end

-- Studs above the head of the point a touch player aims through (the cross of AimReticle).
local TOUCH_AIM_OFFSET = Vector3.new(0, 7.5, 0)

-- The default aim point of a device without a cursor, moved by the player's aim offset
-- ("Custom" control layout; zero otherwise) and kept inside the picture.
local function withAimOffset(camera: Camera, point: Vector2): Vector2
	local offset: Vector2 = ControlsController:GetAimOffset()
	if offset.X == 0 and offset.Y == 0 then
		return point
	end
	local size = camera.ViewportSize
	return Vector2.new(
		math.clamp(point.X + offset.X * size.X, AIM_MARGIN, math.max(AIM_MARGIN, size.X - AIM_MARGIN)),
		math.clamp(point.Y + offset.Y * size.Y, AIM_MARGIN, math.max(AIM_MARGIN, size.Y - AIM_MARGIN))
	)
end

--[[
	Where on the viewport (pixels, top bar included) the player aims without a tap: the
	cursor with a mouse; with a gamepad the cursor too, wherever the engine shows it (the
	centre of the screen only when no pointer is drawn at all); on
	a touch screen a point above the character's head, clear of the character itself and
	of the thumbs. With a gamepad or on a touch screen the "Custom" control layout then
	moves the point by the player's aim offset, a share of the viewport. On a gamepad the
	engine's pointer is not ours to move: it stays where the default point is, and the
	cross AimReticle then draws on the moved point is the aim.
]]
function InputController:GetAimPoint(): Vector2
	local camera = Workspace.CurrentCamera
	if deviceKind == "KeyboardMouse" or not camera then
		return UserInputService:GetMouseLocation()
	end
	local centre = camera.ViewportSize / 2
	if deviceKind ~= "Touch" then
		return withAimOffset(camera, gamepadCursor(camera) or centre)
	end
	local character = localPlayer.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return withAimOffset(camera, centre)
	end
	local point, onScreen = camera:WorldToViewportPoint(head.Position + TOUCH_AIM_OFFSET)
	return withAimOffset(camera, if onScreen then Vector2.new(point.X, point.Y) else centre)
end

-- The character the aim would land on from the aim point: the camera lock's target, else
-- the one the assistance picks, if any.
function InputController:GetAssistTarget(): BasePart?
	local locked = CameraLockController:GetTarget()
	if locked then
		return locked
	end
	local camera = Workspace.CurrentCamera
	if not camera or not InputController:IsAimAssisted() then
		return nil
	end
	return AimAssist.FindTarget(camera, InputController:GetAimPoint(), localPlayer.Character)
end

function InputController:GetControllerType(): string
	return controllerType
end

function InputController:GetControllerMode(): ControllerMode
	return controllerMode
end

function InputController:GetHeldMenu(): number?
	return activeMenu
end

function InputController:GetSelectedAbility(): number
	return selectedAbility
end

--[[
	World point the player is aiming at: under the tap while a tap action is being
	dispatched, under the cursor otherwise (the screen centre with the mouse locked).
	Kept inside the range the server accepts, measured from the character.
]]
function InputController:GetAimPosition(): Vector3
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local root = character and character.PrimaryPart
	if not camera then
		return if root then root.Position else Vector3.zero
	end

	-- The point aimed at, in viewport pixels (top bar included).
	local point: Vector2
	if tapPoint then
		point = Vector2.new(tapPoint.X, tapPoint.Y) + GuiService:GetGuiInset()
	else
		point = InputController:GetAimPoint()
	end

	local reach = AbilityConfig.HardMaxAimDistance * 0.9
	local position: Vector3
	local target = CameraLockController:GetTarget()
	if not target and (tapPoint or deviceKind ~= "KeyboardMouse") and SettingsController:Get("Aim_Assist") ~= false then
		target = AimAssist.FindTarget(camera, point, character)
	end
	if target then
		position = target.Position
	else
		local ray = camera:ViewportPointToRay(point.X, point.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		if character then
			params.FilterDescendantsInstances = { character }
		end
		local result = Workspace:Raycast(ray.Origin, ray.Direction * reach, params)
		position = if result then result.Position else ray.Origin + ray.Direction * reach
	end

	if root then
		local offset = position - root.Position
		if offset.Magnitude > reach then
			position = root.Position + offset.Unit * reach
		end
	end
	return position
end

function InputController:KnitInit()
	DataController = Knit.GetController("DataController")
	SettingsController = Knit.GetController("SettingsController")
	CameraLockController = Knit.GetController("CameraLockController")
	ControlsController = Knit.GetController("ControlsController")
end

function InputController:KnitStart()
	-- Every gamepad button, above the engine's own bindings (jump, backpack, camera zoom).
	local padButtons: { Enum.KeyCode } = {}
	for keyName in InputConfig.Keys.GP do
		local keyCode = toKeyCode(keyName)
		if keyCode then
			table.insert(padButtons, keyCode)
		end
	end
	ContextActionService:BindActionAtPriority(
		PAD_ACTION,
		onPad,
		false,
		Enum.ContextActionPriority.High.Value + 50,
		table.unpack(padButtons)
	)

	local HakiService = Knit.GetService("HakiService")

	DataController:Observe("Hotkeys", rebuildBindings)
	DataController:Observe("Settings.ControllerType", rebuildBindings)
	DataController:Observe("DevilFruits.Slot2.Name", function()
		setSelection(selectedAbility)
	end)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.TouchTap:Connect(onTouchTap)
	UserInputService.LastInputTypeChanged:Connect(onLastInputType)
	-- The server starts from "KeyboardMouse": tell it about a phone at once.
	if deviceKind ~= "KeyboardMouse" then
		Knit.GetService("InputService").Device:Fire(deviceKind)
	end
	onLastInputType(UserInputService:GetLastInputType())
	-- A key released while the window is not focused never reports its end.
	UserInputService.WindowFocusReleased:Connect(releaseAll)

	InputController:OnAction("Haki", function(phase: Phase)
		if phase == "Begin" then
			HakiService.ToggleArmament:Fire()
		end
	end)
	InputController:OnAction("Observation", function(phase: Phase)
		if phase == "Begin" then
			HakiService.ToggleObservation:Fire()
		end
	end)
	-- Conqueror's Haki: the press is all the server is told (ConquerorService). Switched
	-- off (ConquerorConfig.Enabled), the action has no key, no button and no listener.
	if InputConfig.IsEnabled("Conq") then
		local ConquerorService = Knit.GetService("ConquerorService")
		InputController:OnAction("Conq", function(phase: Phase)
			if phase == "Begin" then
				ConquerorService.Activate:Fire()
			end
		end)
	end
end

return InputController
