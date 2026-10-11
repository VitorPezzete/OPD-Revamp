--!strict
--[[
	A scrolling list or grid on a sunken background. The canvas follows the content.

		UI.Scroll(scope, { Size = UDim2.fromScale(1, 1), Gap = 8, Children = rows })
		UI.Scroll(scope, { Size = ..., CellSize = Vector2.new(120, 140), Children = cards })   -- grid

	Children are ordered by LayoutOrder. Rows of a list usually use Size = UDim2.new(1, 0, 0, height).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Props = Theme.Layout & {
	-- Horizontal scrolls sideways (a strip of cards); the default scrolls down.
	Direction: ("Vertical" | "Horizontal")?,
	Gap: number?,
	Padding: number?,
	-- Giving a cell size makes it a grid.
	CellSize: Vector2?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	-- false: no background, only the scrolling behaviour.
	Background: boolean?,
	Children: Fusion.Child?,
}

return function(scope: Scope, props: Props): ScrollingFrame
	local horizontal = props.Direction == "Horizontal"
	local gap = props.Gap or Theme.Space.S
	local padding = props.Padding or Theme.Space.S
	local cell = props.CellSize

	return scope:New("ScrollingFrame")(Theme.place(props, {
		Name = "Scroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Sunken,
		BackgroundTransparency = if props.Background == false then 1 else Theme.Transparency.Sunken,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Colors.Border,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Medium) }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, padding),
				PaddingBottom = UDim.new(0, padding),
				PaddingLeft = UDim.new(0, padding),
				PaddingRight = UDim.new(0, padding),
			}),
			if cell
				then scope:New("UIGridLayout")({
					CellSize = UDim2.fromOffset(cell.X, cell.Y),
					CellPadding = UDim2.fromOffset(gap, gap),
					FillDirection = if horizontal then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
					HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				else scope:New("UIListLayout")({
					FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
					HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
					Padding = UDim.new(0, gap),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			props.Children,
		} :: { any },
	})) :: any
end
