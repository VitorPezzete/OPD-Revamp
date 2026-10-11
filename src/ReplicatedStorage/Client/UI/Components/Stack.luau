--!strict
--[[
	An invisible frame that lays its children out in a row or a column.

		UI.Stack(scope, { Direction = "Horizontal", Gap = Theme.Space.S, Children = { a, b, c } })

	Children are ordered by LayoutOrder. Without a Size the stack wraps its content.
	Wraps = true turns it into a flowing grid of unequal items.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Props = Theme.Layout & {
	Direction: ("Vertical" | "Horizontal")?,
	Gap: number?,
	Padding: number?,
	HorizontalAlignment: Enum.HorizontalAlignment?,
	VerticalAlignment: Enum.VerticalAlignment?,
	AutomaticSize: Enum.AutomaticSize?,
	Wraps: boolean?,
	Children: Fusion.Child?,
}

return function(scope: Scope, props: Props): Frame
	local horizontal = props.Direction == "Horizontal"
	local padding = props.Padding or 0

	return scope:New("Frame")(Theme.place(props, {
		Name = "Stack",
		BackgroundTransparency = 1,
		AutomaticSize = props.AutomaticSize or (if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY),
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
				HorizontalAlignment = props.HorizontalAlignment or Enum.HorizontalAlignment.Left,
				VerticalAlignment = props.VerticalAlignment or Enum.VerticalAlignment.Top,
				Padding = UDim.new(0, props.Gap or Theme.Space.S),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = props.Wraps or false,
			}),
			if padding > 0
				then scope:New("UIPadding")({
					PaddingTop = UDim.new(0, padding),
					PaddingBottom = UDim.new(0, padding),
					PaddingLeft = UDim.new(0, padding),
					PaddingRight = UDim.new(0, padding),
				})
				else nil,
			props.Children,
		} :: { any },
	})) :: any
end
