--!strict
--[[
	The window of a talking merchant: portrait and name on the left, what he says on the
	right, then whatever the screen adds below (offers, progress, buttons).

		Dialogue(scope, {
			Title = "Haki Master",                 -- header of the window
			Speaker = "Silvers Rayleigh",
			Portrait = "rbxassetid://2776110574",
			Text = line,                           -- state or string
			Actions = { nextButton },              -- right-aligned row under the text
			Size = UDim2.fromOffset(760, 300),
			Children = { ... },                    -- "Content": the body below the speech
		})

	No close button: these dialogs close when the character walks away
	(MerchantDialogue.closeOnMove). Without Children the speech fills the whole body.
	Not part of Components/init: require it by its path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Image = require(script.Parent.Image)
local Label = require(script.Parent.Label)
local Panel = require(script.Parent.Panel)
local Window = require(script.Parent.Window)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Title: UsedAs<string>,
	Subtitle: UsedAs<string>?,
	Speaker: UsedAs<string>,
	Portrait: UsedAs<string>,
	Text: UsedAs<string>,
	Actions: Fusion.Child?,
	-- Height of the portrait / speech band when there is content below it.
	SpeechHeight: number?,
	Children: Fusion.Child?,
}

local PORTRAIT = 132
local NAME_HEIGHT = 26
local ACTIONS_HEIGHT = 44

return function(scope: Scope, props: Props): Frame
	local hasContent = props.Children ~= nil
	local hasActions = props.Actions ~= nil
	local speechHeight = props.SpeechHeight or (PORTRAIT + NAME_HEIGHT + Theme.Space.XS)
	local left = PORTRAIT + Theme.Space.L
	local textBottom = if hasActions then ACTIONS_HEIGHT + Theme.Space.S else 0

	return Window(scope, {
		Name = props.Name or "Dialogue",
		Title = props.Title,
		Subtitle = props.Subtitle,
		Size = props.Size or UDim2.fromOffset(760, 300),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		Children = {
			scope:New("Frame")({
				Name = "Speech",
				Size = if hasContent then UDim2.new(1, 0, 0, speechHeight) else UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					Image(scope, {
						Name = "Portrait",
						Image = props.Portrait,
						Size = UDim2.fromOffset(PORTRAIT, PORTRAIT),
						Background = Theme.Colors.Sunken,
						Radius = Theme.Radius.Medium,
						ScaleType = Enum.ScaleType.Crop,
						Children = {
							scope:New("UIStroke")({ Color = Theme.Colors.BorderStrong, Thickness = 1.5 }),
						},
					}),
					Label(scope, {
						Name = "Speaker",
						Text = props.Speaker,
						Variant = "BodyBold",
						Color = Theme.Colors.Accent,
						Scaled = true,
						Position = UDim2.fromOffset(0, PORTRAIT + Theme.Space.XS),
						Size = UDim2.fromOffset(PORTRAIT, NAME_HEIGHT),
					}),
					Panel(scope, {
						Name = "Bubble",
						Position = UDim2.fromOffset(left, 0),
						Size = UDim2.new(1, -left, 1, 0),
						Color = Theme.Colors.Sunken,
						Padding = Theme.Space.M,
						Gradient = false,
						Children = {
							Label(scope, {
								Name = "Text",
								Text = props.Text,
								Variant = "Body",
								Scaled = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								Size = UDim2.new(1, 0, 1, -textBottom),
							}),
							if hasActions
								then scope:New("Frame")({
									Name = "Actions",
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(1, 0, 0, ACTIONS_HEIGHT),
									BackgroundTransparency = 1,
									[Fusion.Children] = {
										scope:New("UIListLayout")({
											FillDirection = Enum.FillDirection.Horizontal,
											HorizontalAlignment = Enum.HorizontalAlignment.Right,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											Padding = UDim.new(0, Theme.Space.S),
											SortOrder = Enum.SortOrder.LayoutOrder,
										}),
										props.Actions,
									} :: { any },
								})
								else nil,
						} :: { any },
					}),
				},
			}),
			if hasContent
				then scope:New("Frame")({
					Name = "Content",
					Position = UDim2.fromOffset(0, speechHeight + Theme.Space.M),
					Size = UDim2.new(1, 0, 1, -(speechHeight + Theme.Space.M)),
					BackgroundTransparency = 1,
					[Fusion.Children] = props.Children,
				})
				else nil,
		} :: { any },
	})
end
