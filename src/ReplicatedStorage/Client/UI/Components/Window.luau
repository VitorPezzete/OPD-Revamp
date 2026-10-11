--!strict
--[[
	A titled sheet: the title written across the top with a thin rule under it (optional
	close button), then a padded body that holds Children. The standard container of
	every menu, shop and dialog.

		UI.Window(scope, {
			Title = "Storage",
			Size = UDim2.fromOffset(900, 600),   -- design pixels; centred by default
			OnClose = context.Close,             -- omit for a window without a close button
			Children = { ... },                  -- placed inside the body
		})

	The sheet is a dark tint, not a solid box, framed by two thin lines like the border of
	a chart. The body is the frame named "Body": its size is the window minus header and
	padding, so children can use scale sizes against it.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Button = require(script.Parent.Button)
local Label = require(script.Parent.Label)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Title: UsedAs<string>,
	-- Small text at the right of the title (a balance, a counter).
	Subtitle: UsedAs<string>?,
	OnClose: (() -> ())?,
	Padding: number?,
	-- Extra header content, laid out right-to-left before the close button.
	HeaderChildren: Fusion.Child?,
	Children: Fusion.Child?,
}

local HEADER_HEIGHT = 52
-- Gap between the outer line of the frame and the inner one.
local FRAME_INSET = 4

return function(scope: Scope, props: Props): Frame
	local padding = props.Padding or Theme.Space.L

	local window = scope:New("Frame")(Theme.place(props, {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 420),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = Theme.Transparency.Window,
		[Fusion.Children] = {
			scope:New("UIStroke")({
				Color = Theme.Colors.BorderStrong,
				Thickness = Theme.Stroke.Thin,
				Transparency = Theme.Stroke.StrongTransparency,
			}),
			scope:New("Frame")({
				Name = "InnerLine",
				Position = UDim2.fromOffset(FRAME_INSET, FRAME_INSET),
				Size = UDim2.new(1, -FRAME_INSET * 2, 1, -FRAME_INSET * 2),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					scope:New("UIStroke")({
						Color = Theme.Colors.Border,
						Thickness = Theme.Stroke.Thin,
						Transparency = Theme.Stroke.Transparency,
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
				BackgroundTransparency = 1,
				[Fusion.Children] = {
					Label(scope, {
						Name = "Title",
						Text = props.Title,
						Variant = "Title",
						Font = Theme.Fonts.Display,
						Color = Theme.Colors.Accent,
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, Theme.Space.L + FRAME_INSET, 0.5, 2),
						ZIndex = 2,
					}),
					scope:New("Frame")({
						Name = "Rule",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.new(1, -(Theme.Space.L + FRAME_INSET) * 2, 0, 1),
						BackgroundColor3 = Theme.Colors.Border,
						BackgroundTransparency = Theme.Stroke.Transparency,
					}),
					scope:New("Frame")({
						Name = "Actions",
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -(Theme.Space.S + FRAME_INSET), 0.5, 2),
						Size = UDim2.new(0.6, 0, 1, -Theme.Space.S * 2),
						BackgroundTransparency = 1,
						ZIndex = 2,
						[Fusion.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								Padding = UDim.new(0, Theme.Space.S),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							if props.Subtitle
								then Label(scope, {
									Name = "Subtitle",
									Text = props.Subtitle,
									Variant = "Body",
									Color = Theme.Colors.TextMuted,
									LayoutOrder = 1,
								})
								else nil,
							props.HeaderChildren,
							if props.OnClose
								then Button(scope, {
									Name = "Close",
									Text = "X",
									Variant = "Ghost",
									TextColor = Theme.Colors.Text,
									Size = UDim2.fromOffset(34, 34),
									LayoutOrder = 100,
									OnClick = props.OnClose,
								})
								else nil,
						} :: { any },
					}),
				},
			}),

			scope:New("Frame")({
				Name = "Body",
				Position = UDim2.fromOffset(padding, HEADER_HEIGHT + padding),
				Size = UDim2.new(1, -padding * 2, 1, -(HEADER_HEIGHT + padding * 2)),
				BackgroundTransparency = 1,
				[Fusion.Children] = props.Children,
			}),
		},
	})) :: any

	-- The gamepad's B closes it like the close button (NavigationController).
	if props.OnClose then
		Closers.register(scope, window, props.OnClose)
	end
	return window
end
