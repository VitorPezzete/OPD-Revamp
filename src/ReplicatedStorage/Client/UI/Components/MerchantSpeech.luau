--!strict
--[[
	What a merchant says: portrait, name and a line of dialogue in a sunken box. The top
	part of every merchant window.

		MerchantSpeech(scope, {
			Portrait = "rbxassetid://123",       -- optional
			Speaker = "Chef",                    -- optional
			Text = line,                         -- string or state
			Height = 132,                        -- design pixels (default); as wide as its parent
		})

	The text shrinks to fit the box: the lines are of very different lengths.
	Not part of Components/init: require it by its path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Image = require(script.Parent.Image)
local Label = require(script.Parent.Label)
local Panel = require(script.Parent.Panel)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = {
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Visible: UsedAs<boolean>?,
	Height: number?,
	Portrait: string?,
	Speaker: UsedAs<string>?,
	Text: UsedAs<string>,
}

local DEFAULT_HEIGHT = 132
local NAME_HEIGHT = 26
local PADDING = Theme.Space.M

return function(scope: Scope, props: Props): Frame
	local height = props.Height or DEFAULT_HEIGHT
	local hasPortrait = props.Portrait ~= nil and props.Portrait ~= ""
	local hasSpeaker = props.Speaker ~= nil
	-- The portrait is a square as tall as the inside of the box; the text starts after it.
	local side = height - PADDING * 2
	local left = if hasPortrait then side + PADDING else 0
	local top = if hasSpeaker then NAME_HEIGHT else 0

	return Panel(scope, {
		Name = props.Name or "Speech",
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		Color = Theme.Colors.Sunken,
		Padding = PADDING,
		Gradient = false,
		Children = {
			if hasPortrait
				then Image(scope, {
					Name = "Portrait",
					Image = props.Portrait :: string,
					Background = Theme.Colors.Raised,
					Radius = Theme.Radius.Medium,
					ScaleType = Enum.ScaleType.Crop,
					Size = UDim2.fromOffset(side, side),
				})
				else nil,
			if hasSpeaker
				then Label(scope, {
					Name = "Speaker",
					Text = props.Speaker :: any,
					Variant = "BodyBold",
					Color = Theme.Colors.Accent,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					Position = UDim2.fromOffset(left, 0),
					Size = UDim2.new(1, -left, 0, NAME_HEIGHT),
				})
				else nil,
			Label(scope, {
				Name = "Text",
				Text = props.Text,
				Variant = "Muted",
				Scaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(left, top),
				Size = UDim2.new(1, -left, 1, -top),
			}),
		} :: { any },
	})
end
