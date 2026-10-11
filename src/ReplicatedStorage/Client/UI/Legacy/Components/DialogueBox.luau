--!strict
--[[
	The dialogue window of the old quest givers (QuestHaki, QuestFish, QuestDF,
	LegendaryQuests): a see-through tinted box with a blue border, a second one inside
	it, the name of the place across the top, and under it whatever the screen puts
	there - usually the dark box the character speaks in, the character's picture with
	its name above, and an answer button.

		DialogueBox.new(scope, {
			Title = "Haki Master",
			Color = OUTER, InnerColor = INNER,
			Children = { DialogueBox.speech(scope, {...}), DialogueBox.portrait(scope, {...}) },
		})

	The inner box is named "Window": NavigationController gives the gamepad selection to
	a screen holding one. These windows have no close button (walking away closes them),
	so nothing is registered for B.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Title: UsedAs<string>,
	-- The tint of the outer box and of the one inside it.
	Color: Color3,
	InnerColor: Color3,
	InnerTransparency: number?,
	-- Design pixels; the old windows took 70% of a 1920x1080 screen.
	Size: Vector2?,
	Children: Fusion.Child?,
}

export type SpeechProps = Kit.Layout & {
	Text: UsedAs<string>,
	TextSize: number?,
}

export type PortraitProps = Kit.Layout & {
	Image: UsedAs<string>,
	-- The character's name, written above the picture.
	Speaker: UsedAs<string>,
	-- Side of the picture, in design pixels.
	Side: number?,
	-- Drawn over the picture (the old "Upgrade?" bubble).
	Children: Fusion.Child?,
}

local DEFAULT_SIZE = Vector2.new(1280, 720)
local BORDER_COLOR = Color3.fromRGB(28, 69, 255)
local BORDER = 3
local TINT_TRANSPARENCY = 0.5
-- Between the outer box and the inner one (the old 2.5%).
local INSET = 24
local TITLE_HEIGHT = 64
local NAME_HEIGHT = 44
local DEFAULT_SIDE = 228

local DialogueBox = {}

local function border(scope: Scope): Instance
	return scope:New("UIStroke")({
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = BORDER_COLOR,
		Thickness = BORDER,
		LineJoinMode = Enum.LineJoinMode.Miter,
	})
end

function DialogueBox.new(scope: Scope, props: Props): Instance
	local size = props.Size or DEFAULT_SIZE
	return Kit.Panel(scope, {
		Name = "Frame",
		Image = "",
		Color = props.Color,
		Transparency = TINT_TRANSPARENCY,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Padding = INSET,
		Children = {
			border(scope),
			Kit.Panel(scope, {
				Name = "Window",
				Image = "",
				Color = props.InnerColor,
				Transparency = props.InnerTransparency or TINT_TRANSPARENCY,
				Size = UDim2.fromScale(1, 1),
				Padding = Kit.Space.L,
				Children = {
					border(scope),
					Kit.Label(scope, {
						Name = "Shop",
						Text = props.Title,
						TextSize = Kit.TextSize.Title,
						Fit = true,
						Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
					}),
					scope:New("Frame")({
						Name = "Body",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(0, TITLE_HEIGHT + Kit.Space.S),
						Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + Kit.Space.S)),
						[Fusion.Children] = props.Children,
					}),
				} :: { any },
			}),
		} :: { any },
	})
end

-- The dark box the character speaks in. Needs a Size.
function DialogueBox.speech(scope: Scope, props: SpeechProps): Instance
	return Kit.Well(
		scope,
		Kit.place(props, {
			Name = "Dia",
			Transparency = 0.7,
			Padding = Kit.Space.L,
			Children = {
				Kit.Label(scope, {
					Name = "Text",
					Text = props.Text,
					TextSize = props.TextSize or Kit.TextSize.Heading,
					-- A long line shrinks to the box instead of running out of it.
					Fit = true,
					Size = UDim2.fromScale(1, 1),
				}),
			},
		}) :: any
	)
end

-- The character: its name over its picture. Wraps its content.
function DialogueBox.portrait(scope: Scope, props: PortraitProps): Instance
	local side = props.Side or DEFAULT_SIDE
	return Kit.Stack(
		scope,
		Kit.place(props, {
			Name = "NPC",
			Gap = Kit.Space.XS,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Children = {
				Kit.Label(scope, {
					Name = "LabelName",
					Text = props.Speaker,
					TextSize = Kit.TextSize.Heading,
					Fit = true,
					Size = UDim2.fromOffset(side, NAME_HEIGHT),
					LayoutOrder = 1,
				}),
				Kit.Image(scope, {
					Name = "Picture",
					Image = props.Image,
					Size = UDim2.fromOffset(side, side),
					LayoutOrder = 2,
					Children = props.Children,
				}),
			},
		}) :: any
	)
end

return DialogueBox
