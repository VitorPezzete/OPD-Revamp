--!strict
--[[
	Text. The variant picks font, size and colour; everything can be overridden.

		UI.Label(scope, { Text = "Storage", Variant = "Title" })
		UI.Label(scope, { Text = beriText, Variant = "Body", Color = Theme.Colors.Beri })

	Variants: Display, Title, Heading, Body (default), BodyBold, Muted, Small, Tiny.
	Without a Size the label is as large as its text (AutomaticSize).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Variant = "Display" | "Title" | "Heading" | "Body" | "BodyBold" | "Muted" | "Small" | "Tiny"

export type Props = Theme.Layout & {
	Text: UsedAs<string>,
	Variant: Variant?,
	Color: UsedAs<Color3>?,
	TextSize: number?,
	Font: Font?,
	TextXAlignment: Enum.TextXAlignment?,
	TextYAlignment: Enum.TextYAlignment?,
	Wrapped: boolean?,
	RichText: boolean?,
	-- Shrinks the text to fit the Size instead of using the variant size (long names).
	Scaled: boolean?,
	Transparency: UsedAs<number>?,
	-- A light halo around the ink, for text drawn straight over the 3D world.
	Outline: boolean?,
	-- The halo's line, when the default (1.5 px, Halo colour, partly see-through) is not wanted.
	OutlineThickness: number?,
	OutlineTransparency: Theme.UsedAs<number>?,
	OutlineColor: Color3?,
	TextTruncate: Enum.TextTruncate?,
	-- Defaults to XY without a Size; Y with a fixed width makes a wrapping paragraph.
	AutomaticSize: Enum.AutomaticSize?,
}

local VARIANTS: { [Variant]: { Font: Font, Size: number, Color: Color3 } } = {
	Display = { Font = Theme.Fonts.Display, Size = Theme.TextSize.Display, Color = Theme.Colors.Text },
	Title = { Font = Theme.Fonts.Heading, Size = Theme.TextSize.Title, Color = Theme.Colors.Text },
	Heading = { Font = Theme.Fonts.Heading, Size = Theme.TextSize.Heading, Color = Theme.Colors.Text },
	Body = { Font = Theme.Fonts.Body, Size = Theme.TextSize.Body, Color = Theme.Colors.Text },
	BodyBold = { Font = Theme.Fonts.BodyBold, Size = Theme.TextSize.Body, Color = Theme.Colors.Text },
	Muted = { Font = Theme.Fonts.Body, Size = Theme.TextSize.Body, Color = Theme.Colors.TextMuted },
	Small = { Font = Theme.Fonts.Body, Size = Theme.TextSize.Small, Color = Theme.Colors.TextMuted },
	Tiny = { Font = Theme.Fonts.Body, Size = Theme.TextSize.Tiny, Color = Theme.Colors.TextDim },
}

return function(scope: Scope, props: Props): TextLabel
	local variant = VARIANTS[props.Variant or "Body"]
	local scaled = props.Scaled == true
	local textSize = props.TextSize or variant.Size
	local authoredRich = props.RichText == true
	-- Numbers are set in their own face, which takes rich text.
	-- A label already set in Arimo as a whole needs nothing wrapped.
	local wholeArimo = props.Font ~= nil and props.Font.Family == Numerals.Family
	local rich = scope:Computed(function(use): boolean
		return authoredRich or (not wholeArimo and Numerals.has(use(props.Text)))
	end)

	return scope:New("TextLabel")(Theme.place(props, {
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = props.AutomaticSize or (if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY),
		FontFace = props.Font or variant.Font,
		Text = scope:Computed(function(use): string
			local text = use(props.Text)
			if wholeArimo or not use(rich) then
				return text
			end
			return Numerals.rich(text, authoredRich)
		end),
		TextColor3 = props.Color or variant.Color,
		TextSize = textSize,
		TextScaled = scaled,
		TextWrapped = props.Wrapped or scaled,
		RichText = rich,
		TextTransparency = props.Transparency or 0,
		TextTruncate = props.TextTruncate or Enum.TextTruncate.None,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		[Fusion.Children] = {
			if scaled then scope:New("UITextSizeConstraint")({ MaxTextSize = textSize, MinTextSize = 8 }) else nil,
			if props.Outline
				then scope:New("UIStroke")({
					Color = props.OutlineColor or Theme.Colors.Halo,
					Thickness = props.OutlineThickness or 1.5,
					Transparency = props.OutlineTransparency or props.Transparency or 0.25,
				})
				else nil,
		} :: { any },
	})) :: any
end
