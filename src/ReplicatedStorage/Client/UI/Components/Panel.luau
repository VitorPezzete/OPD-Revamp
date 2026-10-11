--!strict
--[[
	A square-cornered tint with a thin line around it: the base of every box in the
	interface. At rest it is mostly see-through (Theme.Transparency.Panel); pass
	Transparency for a HUD piece or a more solid box.

		UI.Panel(scope, { Size = UDim2.fromOffset(300, 120), Padding = Theme.Space.M, Children = { ... } })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Color: UsedAs<Color3>?,
	Transparency: UsedAs<number>?,
	Radius: number?,
	-- false removes the border; a Color3 (or state) recolours it.
	Stroke: (boolean | UsedAs<Color3>)?,
	StrokeThickness: number?,
	Padding: number?,
	ClipsDescendants: boolean?,
	AutomaticSize: Enum.AutomaticSize?,
	-- Kept for compatibility: panels are flat.
	Gradient: boolean?,
	Children: Fusion.Child?,
}

return function(scope: Scope, props: Props): Frame
	local stroke = props.Stroke
	local padding = props.Padding or 0
	local recoloured = stroke ~= nil and stroke ~= true and stroke ~= false

	return scope:New("Frame")(Theme.place(props, {
		Name = "Panel",
		BackgroundColor3 = props.Color or Theme.Colors.Surface,
		BackgroundTransparency = if props.Transparency == nil then Theme.Transparency.Panel else props.Transparency,
		ClipsDescendants = props.ClipsDescendants or false,
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		[Fusion.Children] = {
			if stroke == false
				then nil
				else scope:New("UIStroke")({
					Color = if recoloured then stroke :: any else Theme.Colors.Border,
					Thickness = Theme.Stroke.Thin,
					-- A border given its own colour is there to be seen.
					Transparency = if recoloured then Theme.Stroke.StrongTransparency else Theme.Stroke.Transparency,
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
