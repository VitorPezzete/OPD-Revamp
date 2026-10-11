--!strict
--[[
	A square of one colour that can be picked: clothing palettes, skin tones, aura colours.

		Swatch(scope, { Color = color, Selected = isCurrent, OnClick = pick })

	Not part of Components/init: require it by path
	(ReplicatedStorage.Client.UI.Components.Swatch). Without OnClick it only displays.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Color: UsedAs<Color3>,
	Selected: UsedAs<boolean>?,
	Radius: number?,
	OnClick: (() -> ())?,
}

return function(scope: Scope, props: Props): TextButton
	local hovering = scope:Value(false)
	local clickable = props.OnClick ~= nil

	return scope:New("TextButton")(Theme.place(props, {
		Name = "Swatch",
		Size = UDim2.fromOffset(40, 40),
		AutoButtonColor = false,
		Active = clickable,
		Text = "",
		BackgroundColor3 = props.Color,
		[Fusion.OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
		[Fusion.OnEvent("MouseEnter")] = function()
			hovering:set(clickable)
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			hovering:set(false)
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, props.Radius or Theme.Radius.Small) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = scope:Spring(
					scope:Computed(function(use): number
						return if use(props.Selected) then 3.5 else 1.5
					end),
					Theme.Motion.Speed,
					Theme.Motion.Damping
				),
				Color = scope:Computed(function(use): Color3
					if use(props.Selected) then
						return Theme.Colors.Text
					end
					return if use(hovering) then Theme.Colors.Accent else Theme.Colors.Border
				end),
			}),
		},
	})) :: any
end
