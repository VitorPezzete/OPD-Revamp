--!strict
--[[
	A clickable tile: picture on top, title, optional caption under it. Shop items,
	inventory slots, fruits, emotes, auras.

		UI.Card(scope, {
			Title = "Katana",
			Caption = "$ 5,000",                       -- price, level requirement, amount...
			CaptionColor = Theme.Colors.Beri,
			Image = "rbxassetid://123",                 -- or Color for a plain swatch
			Selected = isEquipped,
			OnClick = equip,
		})

	Put it in a UI.Scroll with a CellSize (the card fills its cell), or give it a Size.
	Children are drawn over the picture (badges, viewports).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Label = require(script.Parent.Label)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Title: UsedAs<string>?,
	Caption: UsedAs<string>?,
	CaptionColor: UsedAs<Color3>?,
	Image: UsedAs<string>?,
	ImageColor: UsedAs<Color3>?,
	-- Fills the picture area with a colour (skin dyes, aura colours).
	Color: UsedAs<Color3>?,
	Selected: UsedAs<boolean>?,
	Disabled: UsedAs<boolean>?,
	OnClick: (() -> ())?,
	OnHover: ((hovering: boolean) -> ())?,
	Children: Fusion.Child?,
}

local TEXT_HEIGHT = 22

return function(scope: Scope, props: Props): TextButton
	local hovering = scope:Value(false)
	local lines = (if props.Title then 1 else 0) + (if props.Caption then 1 else 0)
	local footer = lines * TEXT_HEIGHT + (if lines > 0 then Theme.Space.XS else 0)

	return scope:New("TextButton")(Theme.place(props, {
		Name = "Card",
		Size = UDim2.fromOffset(120, 140),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = scope:Spring(
			scope:Computed(function(use): Color3
				if use(props.Selected) then
					return Theme.Colors.PrimaryDark
				end
				return if use(hovering) and not use(props.Disabled) then Theme.Colors.Hover else Theme.Colors.Raised
			end),
			Theme.Motion.Speed,
			Theme.Motion.Damping
		),
		BackgroundTransparency = scope:Computed(function(use): number
			if use(props.Disabled) then
				return 0.8
			end
			return Theme.Transparency.Panel
		end),
		[Fusion.OnEvent("Activated")] = function()
			if props.OnClick and Fusion.peek(props.Disabled) ~= true then
				props.OnClick()
			end
		end,
		[Fusion.OnEvent("MouseEnter")] = function()
			hovering:set(true)
			if props.OnHover then
				props.OnHover(true)
			end
		end,
		[Fusion.OnEvent("MouseLeave")] = function()
			hovering:set(false)
			if props.OnHover then
				props.OnHover(false)
			end
		end,
		[Fusion.Children] = {
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Transparency = scope:Computed(function(use): number
					return if use(props.Selected) then Theme.Stroke.StrongTransparency else Theme.Stroke.Transparency
				end),
				Color = scope:Computed(function(use): Color3
					return if use(props.Selected) then Theme.Colors.BorderStrong else Theme.Colors.Border
				end),
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, Theme.Space.S),
				PaddingBottom = UDim.new(0, Theme.Space.S),
				PaddingLeft = UDim.new(0, Theme.Space.S),
				PaddingRight = UDim.new(0, Theme.Space.S),
			}),
			scope:New("ImageLabel")({
				Name = "Picture",
				Size = UDim2.new(1, 0, 1, -footer),
				BackgroundColor3 = props.Color or Theme.Colors.Sunken,
				BackgroundTransparency = if props.Color then 0 else Theme.Transparency.Sunken,
				Image = props.Image or "",
				ImageColor3 = props.ImageColor or Color3.new(1, 1, 1),
				ScaleType = Enum.ScaleType.Fit,
				[Fusion.Children] = {
					props.Children,
				} :: { any },
			}),
			if props.Title
				then Label(scope, {
					Name = "Title",
					Text = props.Title,
					Variant = "BodyBold",
					TextSize = Theme.TextSize.Small,
					Scaled = true,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, if props.Caption then -TEXT_HEIGHT else 0),
					Size = UDim2.new(1, 0, 0, TEXT_HEIGHT),
				})
				else nil,
			if props.Caption
				then Label(scope, {
					Name = "Caption",
					Text = props.Caption,
					Variant = "Small",
					Color = props.CaptionColor,
					Scaled = true,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, TEXT_HEIGHT),
				})
				else nil,
		} :: { any },
	})) :: any
end
