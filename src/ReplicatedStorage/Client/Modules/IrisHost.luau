--!strict
--[[
	The one copy of Iris on a client, shared by the menus drawn with it. It knows nothing
	about them: a menu is code the server hands to the client that may have it
	(Client.Modules.MenuLoader), and it registers itself here.

		local Iris = IrisHost.Get()             -- required and initialised on the first call
		IrisHost.Watch(function() return opened:get() end)
		IrisHost.Wake()                         -- when a window has just been opened
		IrisHost.Fit(size)                      -- size and position that fit this screen
		IrisHost.AddToggle({ Label = "MENU", Toggle = toggle, IsOpen = isOpen })

	Iris is only ever required by a client the server authorised for one of the menus: this
	module itself requires nothing until Get is called.

	Iris has no cycle of its own here. It is cycled from a Heartbeat connection that exists
	only while some watched window is open (and for a few frames after the last one closes,
	which Iris needs to take its instances down), so a closed menu costs nothing.

	Iris is a mouse and keyboard library. What it lacks for a phone or a console is here:

	Opening   a menu registered with AddToggle gets a small button on touch screens, and on
	          a gamepad opens by holding View / Select (with its Modifier button held, when
	          it has one). The keyboard key stays with the menu's own controller.
	Gamepad   an opening menu takes the engine's selection (D-pad / stick to move, A to
	          press, as in the rest of the interface: NavigationController); B closes it and
	          a closed menu gives the selection back. Sliders cannot be dragged with a pad.
	Touch     Iris ends a slider or number drag only when the left mouse button is released,
	          which a finger never does: the drag stayed active and followed every later
	          touch. A finger lifted is reported to Iris as that button too.
	Size      text and paddings are larger on a touch-only device and on a TV, and Fit keeps
	          a window inside the screen.
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- The ScreenGui Iris draws in, above the game's own interface.
local HOST_GUI = "IrisHost"
local HOST_DISPLAY_ORDER = 150
-- Cycles Iris still needs after the last window closes.
local SETTLE_CYCLES = 3

-- Seconds View / Select is held to open a menu (a tap belongs to NavigationController).
local HOLD_SECONDS = 0.6
local HOLD_BUTTON = Enum.KeyCode.ButtonSelect
local BACK_BUTTON = Enum.KeyCode.ButtonB
-- The engine drops the selection on B itself, sometimes first: one dropped this recently counts.
local BACK_GRACE = 0.25
-- Frames before an opened window has its buttons laid out.
local FOCUS_FRAMES = 3
-- Pixels kept free around a window.
local SCREEN_MARGIN = 8
local TOGGLE_SIZE = Vector2.new(46, 26)

-- Iris config deltas (its default is Dear ImGui's: 13 px text, 3 px paddings).
local TOUCH_STYLE = {
	TextSize = 15,
	FramePadding = Vector2.new(8, 7),
	ItemSpacing = Vector2.new(8, 8),
	ScrollbarSize = 12,
	GrabMinSize = 18,
}
local TV_STYLE = {
	TextSize = 18,
	FramePadding = Vector2.new(8, 6),
	ItemSpacing = Vector2.new(10, 8),
	ScrollbarSize = 10,
}

export type Toggle = {
	-- Text of the on-screen button (touch).
	Label: string,
	Toggle: () -> (),
	IsOpen: () -> boolean,
	-- Gamepad button that must be held with View / Select; nil for the menu that opens without one.
	Modifier: Enum.KeyCode?,
}

local IrisHost = {}

local Iris: any = nil
local watchers: { () -> boolean } = {}
local cycle: RBXScriptConnection? = nil
local settle = 0
local fps = 60
local host: ScreenGui? = nil
local toggles: { Toggle } = {}
local toggleBar: Frame? = nil
local wasOpen = false
-- When the selection last left an Iris window; math.huge while it is inside one.
local lastSelectedAt = -math.huge

--[[
	Where Iris draws. Left to itself it puts a Folder ("Iris_Root") in the PlayerGui, and
	the engine clears everything out of the PlayerGui that is not a ScreenGui with
	ResetOnSpawn off each time the character is loaded again: after the first death the
	folder was gone, the menus could not be drawn any more and Iris errored on every mouse
	move. It is given one ScreenGui of ours instead, which outlives the character, and told
	to build its windows as frames inside it (its UseScreenGUIs option, off).
]]
local function makeHost(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = HOST_GUI
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = HOST_DISPLAY_ORDER
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

--[[
	Iris reads the input service through one field of its utility table, and connects to
	its events when it is initialised. Before that, the field is swapped for a stand-in
	that forwards everything and only differs in InputEnded: a touch that ends is also
	reported as the left mouse button released (see "Touch" at the top).
]]
local function reportTouchAsMouse()
	local utility = Iris.Internal._utility
	local real = utility and utility.UserInputService
	if typeof(real) ~= "Instance" then
		return
	end

	local inputEnded = {
		Connect = function(_self: any, callback: (...any) -> ()): RBXScriptConnection
			return real.InputEnded:Connect(function(input: InputObject, processed: boolean)
				callback(input, processed)
				if input.UserInputType == Enum.UserInputType.Touch then
					callback({
						UserInputType = Enum.UserInputType.MouseButton1,
						UserInputState = Enum.UserInputState.End,
						KeyCode = Enum.KeyCode.Unknown,
						Position = input.Position,
						Delta = input.Delta,
					}, processed)
				end
			end)
		end,
	}
	utility.UserInputService = setmetatable({}, {
		__index = function(_self: any, key: string): any
			if key == "InputEnded" then
				return inputEnded
			end
			local value = (real :: any)[key]
			if type(value) == "function" then
				return function(_proxy: any, ...: any): ...any
					return value(real, ...)
				end
			end
			return value
		end,
	})
end

local function irisRoot(): Instance?
	return host
end

local function isShown(object: GuiObject, root: Instance): boolean
	local current: Instance? = object
	while current and current ~= root do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return current == root
end

local function inIris(object: Instance?): boolean
	local root = irisRoot()
	return object ~= nil and root ~= nil and object:IsDescendantOf(root)
end

local function usingGamepad(): boolean
	return string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
end

-- The selection goes to the first tab of the window that is up, or to its first button.
local function focusWindow()
	local root = irisRoot()
	if not root then
		return
	end
	local best: GuiObject? = nil
	local bestIsTab = false
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and isShown(descendant, root) then
			local isTab = descendant:FindFirstAncestor("Iris_TabBar") ~= nil
			local better = best == nil or (isTab and not bestIsTab)
			if not better and isTab == bestIsTab and best then
				local a, b = descendant.AbsolutePosition, best.AbsolutePosition
				better = a.Y < b.Y - 1 or (math.abs(a.Y - b.Y) <= 1 and a.X < b.X)
			end
			if better then
				best, bestIsTab = descendant, isTab
			end
		end
	end
	if best then
		GuiService.SelectedObject = best
	end
end

local function anyOpen(): boolean
	for _, isOpen in watchers do
		if isOpen() then
			return true
		end
	end
	return false
end

function IrisHost.Get(): any
	if not Iris then
		Iris = (require :: any)(ReplicatedStorage.Shared.Packages.Iris)
		-- Guarded: it leans on Iris internals, and the menus work without it.
		local ok, problem = pcall(reportTouchAsMouse)
		if not ok then
			warn(`[IrisHost] touch drags will not end: {tostring(problem)}`)
		end
		local gui = makeHost()
		host = gui
		Iris.UpdateGlobalConfig({ UseScreenGUIs = false })
		Iris.Init(gui, false)

		if GuiService:IsTenFootInterface() then
			Iris.UpdateGlobalConfig(TV_STYLE)
		elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			Iris.UpdateGlobalConfig(TOUCH_STYLE)
		end
	end
	return Iris
end

--[[
	The size a window can have on this screen (never more than `wanted`) and where to put
	it so that all of it is visible: a phone in landscape is shorter than the menus.
]]
function IrisHost.Fit(wanted: Vector2): (Vector2, Vector2)
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local usable = viewport - GuiService:GetGuiInset() - Vector2.new(SCREEN_MARGIN, SCREEN_MARGIN) * 2
	local size = Vector2.new(
		math.max(200, math.min(wanted.X, usable.X)),
		math.max(160, math.min(wanted.Y, usable.Y))
	)
	local position = Vector2.new(
		math.max(SCREEN_MARGIN, math.min(60, usable.X - size.X + SCREEN_MARGIN)),
		math.max(SCREEN_MARGIN, math.min(60, usable.Y - size.Y + SCREEN_MARGIN))
	)
	return size, position
end

-- `isOpen` tells whether a window of the caller is up; Iris runs while any of them is.
function IrisHost.Watch(isOpen: () -> boolean)
	table.insert(watchers, isOpen)
end

function IrisHost.Wake()
	settle = SETTLE_CYCLES
	if cycle or not Iris then
		return
	end
	cycle = RunService.Heartbeat:Connect(function(deltaTime: number)
		fps += (1 / math.max(deltaTime, 1e-4) - fps) * 0.05

		local open = anyOpen()
		if wasOpen and not open and inIris(GuiService.SelectedObject) then
			-- The last menu closed: the stick goes back to the character.
			GuiService.SelectedObject = nil
		end
		wasOpen = open
		if open then
			settle = SETTLE_CYCLES
		elseif settle > 0 then
			settle -= 1
		else
			if cycle then
				cycle:Disconnect()
				cycle = nil
			end
			return
		end
		Iris.Internal._cycle(deltaTime)
	end)

	if usingGamepad() then
		task.spawn(function()
			for _ = 1, FOCUS_FRAMES do
				RunService.Heartbeat:Wait()
			end
			if anyOpen() then
				focusWindow()
			end
		end)
	end
end

local function closeAll()
	for _, toggle in toggles do
		if toggle.IsOpen() then
			toggle.Toggle()
		end
	end
end

local function setupInput()
	-- Held View / Select: the menu whose modifier is down, else the one without a modifier.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == HOLD_BUTTON then
			local gamepad = input.UserInputType
			if string.sub(gamepad.Name, 1, 7) ~= "Gamepad" then
				return
			end
			task.delay(HOLD_SECONDS, function()
				if not UserInputService:IsGamepadButtonDown(gamepad, HOLD_BUTTON) then
					return
				end
				local plain: Toggle? = nil
				for _, toggle in toggles do
					if toggle.Modifier == nil then
						plain = plain or toggle
					elseif UserInputService:IsGamepadButtonDown(gamepad, toggle.Modifier) then
						toggle.Toggle()
						return
					end
				end
				if plain then
					plain.Toggle()
				end
			end)
		elseif input.KeyCode == BACK_BUTTON then
			if inIris(GuiService.SelectedObject) or os.clock() - lastSelectedAt <= BACK_GRACE then
				closeAll()
			end
		end
	end)
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if inIris(GuiService.SelectedObject) then
			lastSelectedAt = math.huge
		elseif lastSelectedAt == math.huge then
			lastSelectedAt = os.clock()
		end
	end)
end

local function addTouchButton(toggle: Toggle)
	if not UserInputService.TouchEnabled then
		return
	end
	local bar = toggleBar
	if not bar then
		local gui = Instance.new("ScreenGui")
		gui.Name = "IrisToggles"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 200
		local frame = Instance.new("Frame")
		frame.Name = "Bar"
		frame.AnchorPoint = Vector2.new(1, 0)
		frame.Position = UDim2.new(1, -SCREEN_MARGIN, 0, SCREEN_MARGIN)
		frame.Size = UDim2.fromOffset(0, TOGGLE_SIZE.Y)
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.BackgroundTransparency = 1
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.Padding = UDim.new(0, 4)
		layout.Parent = frame
		frame.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		toggleBar = frame
		bar = frame
	end

	local button = Instance.new("TextButton")
	button.Name = toggle.Label
	button.Text = toggle.Label
	button.Size = UDim2.fromOffset(TOGGLE_SIZE.X, TOGGLE_SIZE.Y)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	button.BackgroundTransparency = 0.35
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.Font = Enum.Font.Code
	button.BorderSizePixel = 0
	-- Not a stop for the D-pad: a gamepad opens the menu by holding View / Select.
	button.Selectable = false
	button.Activated:Connect(toggle.Toggle)
	button.Parent = bar
end

-- Makes a menu reachable without a keyboard (see "Opening" at the top).
function IrisHost.AddToggle(toggle: Toggle)
	if #toggles == 0 then
		setupInput()
	end
	table.insert(toggles, toggle)
	addTouchButton(toggle)
end

-- Smoothed frame rate of this client, measured while a menu is open.
function IrisHost.GetFps(): number
	return fps
end

return IrisHost
