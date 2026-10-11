--!strict
--[[
	A horizontal bar filled from 0 to 1, animated, with optional text over it.

		UI.ProgressBar(scope, { Value = healthRatio, Color = Theme.Colors.Health, Text = healthText })

	Value is clamped. Overlay (0..1, optional) draws a second, lighter fill on top of the
	first one (shield over health).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Label = require(script.Parent.Label)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Value: UsedAs<number>,
	Color: UsedAs<Color3>?,
	Text: UsedAs<string>?,
	TextSize: number?,
	Overlay: UsedAs<number>?,
	OverlayColor: UsedAs<Color3>?,
	Radius: number?,
	-- false: the fill jumps instead of sliding (bars driven every frame).
	Animated: boolean?,
	Transparency: UsedAs<number>?,
	-- 0-1: fades the whole bar out (fill and line too), for bars that leave the screen.
	Fade: UsedAs<number>?,
	-- The trough behind the fill and the line around the bar.
	TrackColor: UsedAs<Color3>?,
	StrokeColor: UsedAs<Color3>?,
}

local function ratio(scope: Scope, source: UsedAs<number>, animated: boolean): UsedAs<UDim2>
	local size = scope:Computed(function(use): UDim2
		local value = use(source)
		return UDim2.fromScale(if value == value then math.clamp(value, 0, 1) else 0, 1)
	end)
	return if animated then scope:Spring(size, Theme.Motion.SlowSpeed, Theme.Motion.Damping) else size
end

return function(scope: Scope, props: Props): Frame
	local radius = UDim.new(0, props.Radius or Theme.Radius.Small)
	local animated = props.Animated ~= false
	local fade = props.Fade or 0

	return scope:New("Frame")(Theme.place(props, {
		Name = "ProgressBar",
		Size = UDim2.fromOffset(240, 22),
		BackgroundColor3 = props.TrackColor or Theme.Colors.Sunken,
		BackgroundTransparency = props.Transparency or Theme.Transparency.Sunken,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = radius }),
			scope:New("UIStroke")({
				Color = props.StrokeColor or Theme.Colors.Border,
				Thickness = Theme.Stroke.Thin,
				Transparency = scope:Computed(function(use): number
					local own = if props.StrokeColor then 0 else Theme.Stroke.Transparency
					return 1 - (1 - own) * (1 - use(fade))
				end),
			}),
			scope:New("Frame")({
				Name = "Clip",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				[Fusion.Children] = {
					scope:New("Frame")({
						Name = "Fill",
						Size = ratio(scope, props.Value, animated),
						BackgroundColor3 = props.Color or Theme.Colors.Primary,
						BackgroundTransparency = fade,
						[Fusion.Children] = {
							scope:New("UICorner")({ CornerRadius = radius }),
						},
					}),
					if props.Overlay
						then scope:New("Frame")({
							Name = "Overlay",
							Size = ratio(scope, props.Overlay, animated),
							BackgroundColor3 = props.OverlayColor or Theme.Colors.Shield,
							BackgroundTransparency = 0.35,
							ZIndex = 2,
							[Fusion.Children] = { scope:New("UICorner")({ CornerRadius = radius }) },
						})
						else nil,
				} :: { any },
			}),
			if props.Text
				then Label(scope, {
					Name = "Text",
					Text = props.Text,
					Variant = "BodyBold",
					TextSize = props.TextSize or Theme.TextSize.Small,
					Size = UDim2.fromScale(1, 1),
					Outline = true,
					ZIndex = 3,
				})
				else nil,
		} :: { any },
	})) :: any
end
