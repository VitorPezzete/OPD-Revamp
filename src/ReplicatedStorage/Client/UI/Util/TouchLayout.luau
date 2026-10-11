--!strict
--[[
	Where the touch controls go, around the engine's jump button (bottom-right corner):

		        [ fruit 2 abilities ]
		        [ fruit 1 abilities ]      rows stacked above the jump button,
		        [  context buttons  ]      right edges level with it
		                 [ Lock ][ Jump ]  bottom row, bottoms level

	Only one small button shares the bottom row with the jump button: the bottom centre of
	the screen belongs to the engine's tool bar, whose width cannot be measured.

	The jump button's place and size depend on the screen (Roblox draws it 70 px on
	phones, 120 px on tablets), so it is measured (PlayerGui.TouchGui...JumpButton) and
	everything is placed from it. All values are design pixels: the panels that use them
	opt out of ScreenScale's pinning (attribute ScreenScale = false), so the gui's UIScale
	turns them into real pixels exactly.

		TouchLayout.Jump                    Fusion value { Right, Bottom, Size }
		TouchLayout.sidePosition(scope)     UDim2 for an AnchorPoint (1, 1) panel
		TouchLayout.contextPosition(scope)
		TouchLayout.abilitiesPosition(scope)
		TouchLayout.optOut(panel)           marks a panel as placed by hand
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)

type Scope = Fusion.Scope<typeof(Fusion)>
export type JumpRect = {
	-- Design pixels from the right edge of the screen to the jump button's right edge.
	Right: number,
	-- Design pixels from the bottom of the screen to its bottom edge.
	Bottom: number,
	Size: number,
}

local peek = Fusion.peek

-- Real pixels of the engine's button (TouchGui defaults), until the real one is found.
local SMALL_SCREEN = 500
local DEFAULT_SMALL = { Right = 25, Bottom = 20, Size = 70 }
local DEFAULT_LARGE = { Right = 50, Bottom = 90, Size = 120 }

local TouchLayout = {}

TouchLayout.SideSize = 78
TouchLayout.ContextSize = 62
TouchLayout.AbilitySize = 70
TouchLayout.Gap = 8

-- The look of every disc of the touch controls: see-through black, a faint white line.
TouchLayout.Disc = table.freeze({
	Color = Color3.new(0, 0, 0),
	Transparency = 0.55,
	PressedTransparency = 0.3,
	SelectedTransparency = 0.25,
	LineColor = Color3.new(1, 1, 1),
	LineTransparency = 0.7,
})

local rootScope = Fusion.scoped(Fusion)
local jump = rootScope:Value({ Right = 25, Bottom = 20, Size = 70 } :: JumpRect)
TouchLayout.Jump = jump

local button: GuiObject? = nil
local buttonConnections: { RBXScriptConnection } = {}

local function refresh()
	local factor = peek(ScreenScale.Factor)
	local viewport = peek(ScreenScale.Viewport)
	if factor <= 0 then
		return
	end

	local real: { Right: number, Bottom: number, Size: number }
	local current = button
	if current and current.Parent and current.AbsoluteSize.X > 0 then
		local gui = current:FindFirstAncestorWhichIsA("ScreenGui")
		-- AbsolutePosition starts under the top bar unless the gui ignores it.
		local insetY = if gui and not gui.IgnoreGuiInset then GuiService:GetGuiInset().Y else 0
		local position = current.AbsolutePosition + Vector2.new(0, insetY)
		local size = current.AbsoluteSize
		real = {
			Right = viewport.X - (position.X + size.X),
			Bottom = viewport.Y - (position.Y + size.Y),
			Size = size.X,
		}
	else
		real = if math.min(viewport.X, viewport.Y) <= SMALL_SCREEN then DEFAULT_SMALL else DEFAULT_LARGE
	end

	jump:set({
		Right = math.max(0, real.Right) / factor,
		Bottom = math.max(0, real.Bottom) / factor,
		Size = real.Size / factor,
	})
end

local function watch(candidate: Instance)
	if candidate.Name ~= "JumpButton" or not candidate:IsA("GuiObject") then
		return
	end
	for _, connection in buttonConnections do
		connection:Disconnect()
	end
	button = candidate
	buttonConnections = {
		candidate:GetPropertyChangedSignal("AbsolutePosition"):Connect(refresh),
		candidate:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh),
		candidate.AncestryChanged:Connect(refresh),
	}
	refresh()
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
for _, descendant in playerGui:GetDescendants() do
	watch(descendant)
end
playerGui.DescendantAdded:Connect(watch)
rootScope:Observer(ScreenScale.Factor):onChange(refresh)
rootScope:Observer(ScreenScale.Viewport):onChange(refresh)
refresh()

-- The tallest of the jump button and the side button: the height of the bottom row.
local function rowHeight(rect: JumpRect): number
	return math.max(rect.Size, TouchLayout.SideSize)
end

-- Bottom-right corner of the one button left of the jump button, bottoms level.
function TouchLayout.sidePosition(scope: Scope): Fusion.Computed<UDim2>
	return scope:Computed(function(use): UDim2
		local rect = use(jump)
		return UDim2.new(1, -(rect.Right + rect.Size + TouchLayout.Gap), 1, -rect.Bottom)
	end)
end

-- Bottom-right corner of the context buttons row: above the bottom row, level with the
-- jump button's right edge.
function TouchLayout.contextPosition(scope: Scope): Fusion.Computed<UDim2>
	return scope:Computed(function(use): UDim2
		local rect = use(jump)
		return UDim2.new(1, -rect.Right, 1, -(rect.Bottom + rowHeight(rect) + TouchLayout.Gap))
	end)
end

-- Bottom-right corner of the ability rows, above the context buttons.
function TouchLayout.abilitiesPosition(scope: Scope): Fusion.Computed<UDim2>
	return scope:Computed(function(use): UDim2
		local rect = use(jump)
		local bottom = rect.Bottom + rowHeight(rect) + TouchLayout.ContextSize + TouchLayout.Gap * 2
		return UDim2.new(1, -rect.Right, 1, -bottom)
	end)
end

-- A panel placed from these values must not be moved by ScreenScale's pinning.
function TouchLayout.optOut<T>(panel: T): T
	(panel :: any):SetAttribute("ScreenScale", false)
	return panel
end

return TouchLayout
