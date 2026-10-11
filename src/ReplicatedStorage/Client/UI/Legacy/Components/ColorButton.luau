--!strict
--[[
	A flat button in a colour the Kit has no variant for: a palette swatch, the skin dye
	a player owns, the turquoise "pay with gems" button. The colour may be state.

		ColorButton(scope, { Color = dye, Text = name, Size = ..., OnClick = wear })
		ColorButton(scope, { Color = color, Selected = isCurrent, OnClick = pick })   -- a swatch

	Selected draws the green frame of the current choice of a palette, inside the button
	so that neighbours in a tight grid do not cover it. Disabled greys it out, like a
	Kit.Button.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = Kit.Layout & {
	Color: UsedAs<Color3>,
	Text: UsedAs<string>?,
	TextSize: number?,
	TextColor: UsedAs<Color3>?,
	Selected: UsedAs<boolean>?,
	Disabled: UsedAs<boolean>?,
	OnClick: (() -> ())?,
	OnHover: ((hovering: boolean) -> ())?,
	Children: Fusion.Child?,
}

local SELECTED_THICKNESS = 3

return function(scope: Scope, props: Props): ImageLabel
	local function disabled(use: Fusion.Use): boolean
		return props.Disabled ~= nil and use(props.Disabled) == true
	end

	return Kit.Well(scope, {
		Name = props.Name or "ColorButton",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.fromOffset(200, 44),
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		Transparency = 0,
		Color = scope:Computed(function(use): Color3
			return if disabled(use) then Kit.Colors.Grey else use(props.Color)
		end),
		Children = {
			if props.Selected ~= nil
				then scope:New("Frame")({
					Name = "Selected",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -2 * SELECTED_THICKNESS, 1, -2 * SELECTED_THICKNESS),
					Visible = props.Selected,
					[Fusion.Children] = {
						scope:New("UIStroke")({
							Color = Kit.Colors.Selected,
							Thickness = SELECTED_THICKNESS,
							LineJoinMode = Enum.LineJoinMode.Miter,
						}),
					},
				})
				else nil,
			Kit.Button(scope, {
				Name = "Button",
				Variant = "Ghost",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
				Text = props.Text,
				TextSize = props.TextSize,
				TextColor = props.TextColor,
				Disabled = props.Disabled,
				OnClick = props.OnClick,
				OnHover = props.OnHover,
			}),
			props.Children,
		} :: { any },
	})
end
