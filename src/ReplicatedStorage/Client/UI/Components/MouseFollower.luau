--!strict
--[[
	A small panel that follows the mouse: the body of every tooltip. It reads the mouse
	position kept by UI.Util.Tooltip (only tracked while a tip is up) and stays on the
	screen by flipping to the other side of the cursor near the right / bottom edges.

		MouseFollower(scope, { Name = "Tip", Visible = isShown, Children = { ... } })
		MouseFollower(scope, { Visible = isShown, Width = 380, Children = { ... } })   -- fixed width, grows down

	Must be a direct child of the ScreenGui. It opts out of the panel pinning of
	ScreenScale (its position is the cursor, not a place on the reference screen) and
	converts the mouse position from real pixels to design pixels itself.

	Not part of Components/init: require it by path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local ScreenScale = require(ReplicatedStorage.Client.UI.Util.ScreenScale)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local Panel = require(script.Parent.Panel)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = {
	Name: string?,
	Visible: UsedAs<boolean>,
	-- Fixed width in design pixels; without it the panel is as wide as its content.
	Width: number?,
	Padding: number?,
	Children: Fusion.Child?,
}

-- Design pixels between the cursor and the panel.
local GAP = 18
-- Past this share of the screen the panel goes to the other side of the cursor.
local FLIP = 0.6

return function(scope: Scope, props: Props): Frame
	local anchor = scope:Computed(function(use): Vector2
		local mouse = use(Tooltip.Mouse)
		local viewport = use(ScreenScale.Viewport)
		return Vector2.new(
			if mouse.X > viewport.X * FLIP then 1 else 0,
			if mouse.Y > viewport.Y * FLIP then 1 else 0
		)
	end)

	local position = scope:Computed(function(use): UDim2
		local mouse = use(Tooltip.Mouse)
		local factor = use(ScreenScale.Factor)
		local side = use(anchor)
		return UDim2.fromOffset(
			mouse.X / factor + (if side.X == 1 then -GAP else GAP),
			mouse.Y / factor + (if side.Y == 1 then -GAP else GAP)
		)
	end)

	local width = props.Width
	-- AnchorPoint is a state object here, which Panel forwards as it is.
	local panelProps: any = {
		Name = props.Name or "Tip",
		AnchorPoint = anchor,
		Position = position,
		Size = if width then UDim2.fromOffset(width, 0) else UDim2.fromOffset(0, 0),
		AutomaticSize = if width then Enum.AutomaticSize.Y else Enum.AutomaticSize.XY,
		Visible = props.Visible,
		Color = Theme.Colors.Background,
		Stroke = Theme.Colors.BorderStrong,
		Radius = Theme.Radius.Small,
		Padding = props.Padding or Theme.Space.M,
		ZIndex = 10,
		Children = props.Children,
	}
	local panel = Panel(scope, panelProps)
	panel:SetAttribute("ScreenScale", false)
	return panel
end
