--!strict
--[[
	Makes a legacy screen a window for the gamepad, the way UI.Components.Window makes a
	rework one (NavigationController):

	- a screen is given the selection on its first button when it opens only if something
	  in it is named "Window": the generated layouts have no such element, so an empty
	  marker is added;
	- B closes the window holding the selection through UI.Util.Closers. Pass `close` only
	  where the rework twin has a close button; a dialogue the twin only closes by walking
	  away takes the selection and nothing else.

		GamepadWindow.mark(scope, gui, context.Close)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)

type Scope = Fusion.Scope<typeof(Fusion)>

-- The name NavigationController looks for (the frame UI.Components.Window builds).
local WINDOW_MARK = "Window"

local GamepadWindow = {}

function GamepadWindow.mark(scope: Scope, gui: Instance, close: (() -> ())?)
	if not gui:FindFirstChild(WINDOW_MARK, true) then
		-- A Folder: nothing to draw, and nothing for ScreenScale to pin.
		local mark = Instance.new("Folder")
		mark.Name = WINDOW_MARK
		mark.Parent = gui
		table.insert(scope, mark)
	end
	if close then
		Closers.register(scope, gui, close)
	end
end

return GamepadWindow
