--!strict
--[[
	A small pill with a short text: counters, "NEW", levels, a currency amount.

		UI.Badge(scope, { Text = "2", Color = Theme.Colors.Danger })
		UI.Badge(scope, { Text = beriText, Color = Theme.Colors.Beri, Soft = true })

	Soft = true: dark pill with coloured text instead of a coloured pill.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Text: UsedAs<string>,
	Color: UsedAs<Color3>?,
	Soft: boolean?,
	TextSize: number?,
}

return function(scope: Scope, props: Props): TextLabel
	local color = props.Color or Theme.Colors.Primary
	local soft = props.Soft == true

	return scope:New("TextLabel")(Theme.place(props, {
		Name = "Badge",
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
		BackgroundColor3 = if soft then Theme.Colors.Sunken else color,
		BackgroundTransparency = if soft then Theme.Transparency.Sunken else 0,
		FontFace = Theme.Fonts.Heading,
		RichText = true,
		Text = scope:Computed(function(use): string
			return Numerals.rich(use(props.Text), false)
		end),
		TextColor3 = if soft then color else Theme.Colors.TextOnPrimary,
		TextSize = props.TextSize or Theme.TextSize.Small,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Pill) }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
				PaddingLeft = UDim.new(0, Theme.Space.S),
				PaddingRight = UDim.new(0, Theme.Space.S),
			}),
			if soft
				then scope:New("UIStroke")({
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = color,
					Thickness = Theme.Stroke.Thin,
					Transparency = Theme.Stroke.Transparency,
				})
				else nil,
		} :: { any },
	})) :: any
end
