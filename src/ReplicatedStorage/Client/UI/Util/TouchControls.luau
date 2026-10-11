--!strict
--[[
	What makes a touch button of the game follow the control layouts (ControlsController /
	ControlsConfig): where it sits and how large it is ("Custom"), how a touch becomes its
	action ("Auto" and "Custom"), and how the editor drags it around. MobileContext and the
	touch AbilityBar hand each of their buttons to it:

		local control = TouchControls.attach(scope, {
			Id = "Dash",                 -- a key of ControlsConfig.Buttons
			Button = disc,               -- the pressable disc, Size = its default size in design pixels
			Holder = slot,               -- an invisible frame holding its place in the default layout
			Layer = layer,               -- a full-screen frame of the same gui, for moved buttons
			Size = TouchLayout.ContextSize,
			Arm = arm, Fire = fire,      -- what the button does (see below)
		})
		control.Down(input)   control.Up(input)   control.Click()   control.Cancel()

	The screen reports the touches (Down: a finger landed on the disc, Up: the engine says
	it left, Click: the engine's click) and gives the callbacks of the button's kind:
	- Aimed:    Arm() arms the action for the next tap on the world, Fire() uses it at the aim point
	- Toggle:   Fire() switches it
	- Ability:  Begin() / End() are its key going down and up; Latched(on) tells the
	            screen that the key is being held with no finger on the disc (a "Toggle"),
	            so that it can show it

	Place and size. The disc lives in its holder, in the default layout, until the player
	moves it: then it is parented to the layer at a share of the layer's size - the usable
	screen, below the top bar and inside the safe insets - clamped so the whole disc stays
	on it, again whenever the screen changes. The size is a UIScale inside the disc (its
	content scales with it); the holder grows with it, so an unmoved button still pushes
	its neighbours of the default layout. With the layout on "Default" every disc is in its
	holder at scale 1: exactly the default layout.

	Behaviour (ControlsConfig explains each one; ControlsController:GetBehavior says which
	one a button has now - the player's with "Custom", the one of its action with "Auto").
	A press is followed by its own InputObject, heard on the whole screen, so a finger that
	slides off the disc before lifting still ends it. A key held by a button is let go when
	the button is hidden, when its behaviour or the layout changes (another preset chosen,
	another fruit eaten under "Auto"), when the editor opens, when the window loses focus
	and when the screen is closed: nothing can stay held. With "Default" the buttons do
	what they always did: abilities are held, everything else is the engine's click.

	Editing (ControlsController:IsEditing). The discs do nothing: a touch selects the
	button, and dragging it moves it in the editor's draft. Everything here is driven by
	events; nothing runs per frame.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ControlsConfig = require(ReplicatedStorage.Shared.Configs.ControlsConfig)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Config = {
	Id: string,
	Button: GuiObject,
	Holder: GuiObject,
	Layer: GuiObject,
	-- Design pixels of the disc at scale 1.
	Size: number,
	Arm: (() -> ())?,
	Fire: (() -> ())?,
	Begin: (() -> ())?,
	End: (() -> ())?,
	Latched: ((on: boolean) -> ())?,
}

export type Control = {
	Down: (input: InputObject) -> (),
	Up: (input: InputObject) -> (),
	Click: () -> (),
	-- Ends whatever the button holds, without using anything.
	Cancel: () -> (),
	-- The server ended what a toggled key was holding: the key goes up.
	Settle: () -> (),
}

-- What the module keeps of each attached button, to refresh them all from one connection.
type Entry = {
	Place: () -> (),
	Ring: () -> (),
	-- Lets go when the behaviour or the layout is no longer the one the press began with.
	Check: () -> (),
}

local peek = Fusion.peek

local CENTRE = Vector2.new(0.5, 0.5)
local SCALE_NAME = "ControlScale"
local RING_NAME = "Selected"
local RING_THICKNESS = 3
-- Pixels a finger has to travel before the editor takes the touch for a drag.
local DRAG_THRESHOLD = 8

local TouchControls = {}

local controller: any = nil
local entries: { [Entry]: boolean } = {}
-- Touches being followed: called once when the touch ends (lifted: false when it was cancelled).
local following: { [InputObject]: (lifted: boolean) -> () } = {}
-- One button is dragged at a time.
local dragging = false

local function isMouse(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
end

local function finishAll(lifted: boolean)
	for _, finish in table.clone(following) do
		finish(lifted)
	end
end

local function onInputEnded(input: InputObject)
	local finish = following[input]
	if finish then
		finish(input.UserInputState ~= Enum.UserInputState.Cancel)
	elseif isMouse(input) then
		-- A mouse button does not promise the same InputObject for its press and release.
		for held, callback in table.clone(following) do
			if isMouse(held) then
				callback(true)
			end
		end
	end
end

-- The connections every button shares, made when the first one is attached.
local function start()
	if controller then
		return
	end
	controller = Knit.GetController("ControlsController")

	controller.Changed:Connect(function()
		for entry in entries do
			entry.Check()
			entry.Place()
		end
	end)
	controller.EditingChanged:Connect(function()
		-- Whatever is pressed or dragged belongs to the mode that just ended.
		finishAll(false)
		for entry in entries do
			entry.Check()
			entry.Ring()
		end
	end)
	controller.SelectionChanged:Connect(function()
		for entry in entries do
			entry.Ring()
		end
	end)
	Fusion.scoped(Fusion):Observer(ScreenScale.Factor):onChange(function()
		for entry in entries do
			entry.Place()
		end
	end)

	UserInputService.InputEnded:Connect(onInputEnded)
	UserInputService.TouchEnded:Connect(onInputEnded)
	UserInputService.WindowFocusReleased:Connect(function()
		finishAll(false)
	end)
end

-- A share of the layer for the centre of a disc, kept so that the whole disc is on it.
local function clampShare(share: number, half: number, length: number): number
	if length <= 0 then
		return math.clamp(share, 0, 1)
	end
	local margin = half / length
	if margin >= 0.5 then
		return 0.5
	end
	return math.clamp(share, margin, 1 - margin)
end

function TouchControls.attach(scope: Scope, config: Config): Control
	start()

	local id = config.Id
	local definition = ControlsConfig.Buttons[id]
	local kind = definition.Kind
	local button, holder, layer = config.Button, config.Holder, config.Layer

	button.AnchorPoint = CENTRE
	local scaler = Instance.new("UIScale")
	scaler.Name = SCALE_NAME
	scaler.Parent = button

	---------------------------------------------------------------------------------
	-- Place and size.

	local function place()
		local entry = controller:GetButton(id)
		local scale = if entry then entry.Scale else ControlsConfig.Scale.Default
		local side = config.Size * scale
		scaler.Scale = scale
		holder.Size = UDim2.fromOffset(side, side)

		if entry and entry.X and entry.Y then
			local area = layer.AbsoluteSize
			local half = side * peek(ScreenScale.Factor) / 2
			if button.Parent ~= layer then
				button.Parent = layer
			end
			button.Position = UDim2.fromScale(clampShare(entry.X, half, area.X), clampShare(entry.Y, half, area.Y))
		else
			if button.Parent ~= holder then
				button.Parent = holder
			end
			button.Position = UDim2.fromScale(CENTRE.X, CENTRE.Y)
		end
	end

	-- The mark of the button selected in the editor.
	local ring: Frame? = nil
	local function refreshRing()
		local wanted = controller:IsEditing() and controller:GetSelected() == id
		if wanted and not ring then
			local frame = Instance.new("Frame")
			frame.Name = RING_NAME
			frame.BackgroundTransparency = 1
			frame.Size = UDim2.fromScale(1, 1)
			frame.ZIndex = 20
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = frame
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Theme.Colors.Warning
			stroke.Thickness = RING_THICKNESS
			stroke.Parent = frame
			frame.Parent = button
			ring = frame
		elseif not wanted and ring then
			ring:Destroy()
			ring = nil
		end
	end

	---------------------------------------------------------------------------------
	-- Presses.

	-- The touch on the button, if one is.
	local tracked: InputObject? = nil
	-- Ability: the key is down, and whether it goes up with the finger.
	local keyDown = false
	local keyWithFinger = false
	-- os.clock() of the touch a double tap may follow.
	local lastTouch = -math.huge
	-- What the press in progress (or the toggled key) was started under.
	local startedLayout = controller:GetLayout()
	local startedBehavior = controller:GetBehavior(id)

	local function keyUp()
		if keyDown then
			local latched = not keyWithFinger
			keyDown = false
			keyWithFinger = false
			if latched and config.Latched then
				config.Latched(false)
			end
			if config.End then
				config.End()
			end
		end
	end

	local function keyBegin(withFinger: boolean)
		if keyDown then
			return
		end
		keyDown = true
		keyWithFinger = withFinger
		if not withFinger and config.Latched then
			config.Latched(true)
		end
		if config.Begin then
			config.Begin()
		end
	end

	local function fire()
		if config.Fire then
			config.Fire()
		end
	end

	-- The touch ended. lifted: the finger was lifted (false: cancelled, nothing is used).
	local function finish(lifted: boolean)
		local input = tracked
		if not input then
			return
		end
		tracked = nil
		following[input] = nil

		local behavior = startedBehavior
		if kind == "Ability" then
			if keyWithFinger then
				keyUp()
			elseif lifted and behavior == "Release" and not keyDown then
				keyBegin(true)
				keyUp()
			end
		elseif lifted and behavior == "Release" then
			fire()
		end
	end

	local function cancel()
		finish(false)
		keyUp()
		lastTouch = -math.huge
	end

	-- Editor: the touch selects the button, and moves it once it has travelled far enough.
	local function drag(input: InputObject)
		controller:Select(id)
		if dragging or following[input] then
			return
		end
		dragging = true

		local start = Vector2.new(input.Position.X, input.Position.Y)
		-- From the finger to the centre of the disc, so the disc does not jump under it.
		local grab = button.AbsolutePosition + button.AbsoluteSize / 2 - start
		local moving = false
		local mouse = isMouse(input)
		local moved = UserInputService.InputChanged:Connect(function(changed: InputObject)
			if changed ~= input and not (mouse and changed.UserInputType == Enum.UserInputType.MouseMovement) then
				return
			end
			local point = Vector2.new(changed.Position.X, changed.Position.Y)
			if not moving and (point - start).Magnitude < DRAG_THRESHOLD then
				return
			end
			moving = true
			local area = layer.AbsoluteSize
			if area.X <= 0 or area.Y <= 0 then
				return
			end
			local centre = point + grab - layer.AbsolutePosition
			controller:MoveButton(id, centre.X / area.X, centre.Y / area.Y)
		end)
		following[input] = function()
			following[input] = nil
			moved:Disconnect()
			dragging = false
		end
	end

	local function down(input: InputObject)
		if controller:IsEditing() then
			drag(input)
			return
		end
		-- A second finger on the same disc, or a touch already followed: one press at a time.
		if tracked or following[input] then
			return
		end

		local follows = controller:UsesBehaviors()
		local behavior = controller:GetBehavior(id)
		startedLayout = controller:GetLayout()
		startedBehavior = behavior
		tracked = input
		following[input] = finish

		local now = os.clock()
		local second = false
		if behavior == "DoubleTap" then
			second = now - lastTouch <= ControlsConfig.DoubleTapSeconds
			-- A third touch starts a new pair.
			lastTouch = if second then -math.huge else now
		end

		if kind == "Ability" then
			if behavior == "Hold" then
				keyBegin(true)
			elseif behavior == "Toggle" then
				if keyDown then
					keyUp()
				else
					keyBegin(false)
				end
			elseif behavior == "Tap" then
				-- A quick cast: the key goes down and comes up under the same touch.
				if not keyDown then
					keyBegin(true)
					keyUp()
				end
			elseif second then
				keyBegin(true)
			end
		elseif kind == "Aimed" then
			if behavior == "Instant" or second then
				fire()
			end
		elseif follows and (behavior == "Press" or second) then
			-- With the default layout a toggle is the engine's click (Click below).
			fire()
		end
	end

	local function up(input: InputObject)
		local held = tracked
		if held and (held == input or (isMouse(held) and isMouse(input))) then
			finish(true)
		end
	end

	local function click()
		if controller:IsEditing() then
			return
		end
		if kind == "Aimed" then
			if controller:GetBehavior(id) == "Arm" and config.Arm then
				config.Arm()
			end
		elseif kind == "Toggle" and not controller:UsesBehaviors() then
			fire()
		end
	end

	local function settle()
		if keyDown and not keyWithFinger then
			keyUp()
		end
	end

	-- The layout or the behaviour changed under a press or a toggled key: it is let go.
	local function check()
		if controller:IsEditing() then
			cancel()
		elseif controller:GetLayout() ~= startedLayout or controller:GetBehavior(id) ~= startedBehavior then
			cancel()
			startedLayout = controller:GetLayout()
			startedBehavior = controller:GetBehavior(id)
		end
	end

	---------------------------------------------------------------------------------

	local entry: Entry = { Place = place, Ring = refreshRing, Check = check }
	entries[entry] = true

	local connections: { RBXScriptConnection } = {
		-- The screen was resized or turned: the clamp is worked out again.
		layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(place),
		-- Hidden under the finger (the character died, the level was lost): let go.
		button:GetPropertyChangedSignal("Visible"):Connect(function()
			if not button.Visible then
				cancel()
			end
		end),
	}
	table.insert(scope, function()
		entries[entry] = nil
		for _, connection in connections do
			connection:Disconnect()
		end
		cancel()
	end)

	place()
	refreshRing()

	return {
		Down = down,
		Up = up,
		Click = click,
		Cancel = cancel,
		Settle = settle,
	}
end

return TouchControls
