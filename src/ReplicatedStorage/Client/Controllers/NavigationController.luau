--!strict
--[[
	Moving through the interface with a gamepad.

	The engine already moves the selection between buttons with the stick / D-pad and
	presses the selected one with A; what it cannot know is where to start. Here:

	- the View / Select button puts the selection on the side menu (or takes it away,
	  giving the stick back to the character). While a prompt is on screen (SetPrompt: the
	  drop prompt of the item in hand) it goes to the prompt's first button instead;
	- a window that opens while the gamepad is in use (a shop, a dialog, a menu tab
	  screen) gets the selection on its first button;
	- when the screen holding the selection closes, the selection goes back to the menu,
	  or away if the menu is hidden;
	- B closes the window holding the selection, like its close button (UI.Util.Closers).
	  The engine also uses B to drop the selection, and may do so first: the button
	  selected just before counts. Not while the settings tab is waiting for a button to
	  bind (InputController:IsCapturing): that B is the answer, not a "back";
	- a menu tab opened from the side menu with the pad gets the selection on its first
	  button.

	Screens that are not windows (HUD, notifications) never take the selection. The
	selected button is outlined in the theme's cream instead of the engine's blue.
]]
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

local MENU_SCREEN = "MenuNew"
local ACTION_NAME = "GamepadNavigation"
local TOGGLE_BUTTON = Enum.KeyCode.ButtonSelect
local BACK_BUTTON = Enum.KeyCode.ButtonB
-- A selection dropped this recently (by the engine's own B) still counts for B.
local BACK_GRACE = 0.25
-- The frames of MenuNew that hold the open tab's window: beside the column, and (legacy
-- interface) in the middle of the screen.
local MENU_DOCKS = { "Dock", "Center" }
-- A window is recognised by the close button of UI.Window.
local WINDOW_MARK = "Window"

local NavigationController = Knit.CreateController({
	Name = "NavigationController",
})

local InputController
local UIController

local playerGui: PlayerGui
-- A HUD prompt with buttons (not a window): the toggle button reaches it while it shows.
local prompt: Instance? = nil

-- Whether the object and every GuiObject above it are visible, inside an enabled ScreenGui.
local function isShown(object: GuiObject): boolean
	local current: Instance? = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		elseif current:IsA("ScreenGui") then
			return current.Enabled
		end
		current = current.Parent
	end
	return false
end

-- Top-most, then left-most button that can be selected inside `root`.
local function firstButton(root: Instance): GuiObject?
	local best: GuiObject? = nil
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and isShown(descendant) then
			if not best then
				best = descendant
			else
				local a, b = descendant.AbsolutePosition, (best :: GuiObject).AbsolutePosition
				if a.Y < b.Y - 1 or (math.abs(a.Y - b.Y) <= 1 and a.X < b.X) then
					best = descendant
				end
			end
		end
	end
	return best
end

-- The gui of a screen. Not always named after it (the five boat shops share one name).
local function guiOf(screenName: string): Instance?
	return (UIController and UIController:GetInstance(screenName)) or playerGui:FindFirstChild(screenName)
end

local function selectIn(screenName: string): boolean
	local gui = guiOf(screenName)
	local button = gui and firstButton(gui)
	if button then
		GuiService.SelectedObject = button
		return true
	end
	return false
end

local function isWindowScreen(screenName: string): boolean
	local gui = guiOf(screenName)
	return gui ~= nil and gui:FindFirstChild(WINDOW_MARK, true) ~= nil
end

local function onToggle(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
		return Enum.ContextActionResult.Sink
	end
	local button = prompt and firstButton(prompt)
	if button then
		GuiService.SelectedObject = button
	else
		selectIn(MENU_SCREEN)
	end
	return Enum.ContextActionResult.Sink
end

-- The prompt the toggle button goes to while one of its buttons is shown. One at a time.
function NavigationController:SetPrompt(root: Instance)
	prompt = root
end

function NavigationController:ClearPrompt(root: Instance)
	if prompt == root then
		prompt = nil
	end
end

-- After a window closed: the selection goes back to the menu when it was left on nothing.
local function recover()
	local selected = GuiService.SelectedObject
	if not selected or not isShown(selected) then
		GuiService.SelectedObject = nil
		selectIn(MENU_SCREEN)
	end
end

local lastSelected: GuiObject? = nil
local droppedAt = -math.huge

local function onSelectionChanged()
	local selected = GuiService.SelectedObject
	if selected then
		lastSelected = selected
	else
		droppedAt = os.clock()
	end
end

-- With nothing selected (and nothing dropped just now) B belongs to the game (Haki).
local function onBack(input: InputObject)
	if input.KeyCode ~= BACK_BUTTON or InputController:IsCapturing() then
		return
	end
	local target: Instance? = GuiService.SelectedObject
	if not target and os.clock() - droppedAt <= BACK_GRACE then
		target = lastSelected
	end
	if target and Closers.closeContaining(target) then
		lastSelected = nil
		task.delay(0.1, recover)
	end
end

-- A tab window appearing in the menu's dock while the pad is on the menu takes the selection.
local function watchDock(menu: Instance, name: string?)
	if not name then
		for _, dockName in MENU_DOCKS do
			watchDock(menu, dockName)
		end
		return
	end
	local dock = menu:FindFirstChild(name, true)
	if not dock then
		return
	end
	dock.ChildAdded:Connect(function(window: Instance)
		local selected = GuiService.SelectedObject
		if not InputController:IsUsingGamepad() or not selected or not selected:IsDescendantOf(menu) then
			return
		end
		task.defer(function()
			if window.Parent then
				local button = firstButton(window)
				if button then
					GuiService.SelectedObject = button
				end
			end
		end)
	end)
end

function NavigationController:KnitInit()
	InputController = Knit.GetController("InputController")
end

function NavigationController:KnitStart()
	playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	UIController = Knit.GetController("UIController")

	local outline = Instance.new("Frame")
	outline.Name = "GamepadSelection"
	outline.BackgroundTransparency = 1
	outline.Size = UDim2.fromScale(1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Colors.Accent
	stroke.Thickness = 2
	stroke.Parent = outline
	playerGui.SelectionImageObject = outline

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		onToggle,
		false,
		Enum.ContextActionPriority.High.Value,
		TOGGLE_BUTTON
	)

	UIController.ScreenChanged:Connect(function(screenName: string, isOpen: boolean)
		if not InputController:IsUsingGamepad() then
			return
		end
		-- Deferred: the window is built and laid out by then.
		task.defer(function()
			if isOpen then
				if isWindowScreen(screenName) then
					selectIn(screenName)
				end
				return
			end
			local selected = GuiService.SelectedObject
			if selected and not isShown(selected) then
				GuiService.SelectedObject = nil
				selectIn(MENU_SCREEN)
			end
		end)
	end)

	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(onSelectionChanged)
	-- Processed or not: the engine handles B while something is selected.
	UserInputService.InputBegan:Connect(onBack)

	local menu = playerGui:FindFirstChild(MENU_SCREEN)
	if menu then
		watchDock(menu)
	end
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == MENU_SCREEN then
			task.defer(watchDock, child)
		end
	end)

	-- Leaving the gamepad for the mouse or a touch drops a selection left behind.
	InputController.DeviceChanged:Connect(function(usingGamepad: boolean)
		if not usingGamepad then
			GuiService.SelectedObject = nil
		end
	end)
end

return NavigationController
