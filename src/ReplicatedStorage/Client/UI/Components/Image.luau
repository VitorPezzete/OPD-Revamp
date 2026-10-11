--!strict
--[[
	An image, optionally rounded.

		UI.Image(scope, { Image = "rbxassetid://123", Size = UDim2.fromOffset(64, 64), Radius = Theme.Radius.Small })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Image: UsedAs<string>,
	Color: UsedAs<Color3>?,
	Transparency: UsedAs<number>?,
	-- A colour behind the image (icons with transparent backgrounds on a slot).
	Background: UsedAs<Color3>?,
	Radius: number?,
	ScaleType: Enum.ScaleType?,
	Rotation: UsedAs<number>?,
	Children: Fusion.Child?,
}

return function(scope: Scope, props: Props): ImageLabel
	return scope:New("ImageLabel")(Theme.place(props, {
		Name = "Image",
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = props.Background or Theme.Colors.Sunken,
		BackgroundTransparency = if props.Background then 0 else 1,
		Image = props.Image,
		ImageColor3 = props.Color or Color3.new(1, 1, 1),
		ImageTransparency = props.Transparency or 0,
		ScaleType = props.ScaleType or Enum.ScaleType.Fit,
		Rotation = props.Rotation or 0,
		[Fusion.Children] = {
			if props.Radius then scope:New("UICorner")({ CornerRadius = UDim.new(0, props.Radius) }) else nil,
			props.Children,
		} :: { any },
	})) :: any
end
