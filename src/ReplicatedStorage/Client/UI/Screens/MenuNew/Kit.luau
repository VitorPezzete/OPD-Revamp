--!strict
--[[
	Small pieces shared by the tabs of the menu (not a tab itself): where a tab window
	sits, a "label ..... control" row, a < value > stepper, a titled section, a key cap and
	the picture of a gamepad button.

		Kit.Row(scope, { Label = "Music", Children = { Kit.Stepper(scope, { ... }) } })

	A row's hint. A short one sits beside the label, on the row's one line. A long one
	would run under the controls and could not be read: it goes under the label instead,
	wrapped over as many lines as it needs, and the row grows to hold it (HintBelow). The
	label and the controls keep their line at the top of the row, so the controls of
	neighbouring rows stay aligned whatever the length of the descriptions.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local PadIcons = require(ReplicatedStorage.Client.UI.Util.PadIcons)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

local Kit = {}

-- Every tab window grows from the bottom-left corner of the dock, beside the buttons.
Kit.WindowAnchor = Vector2.new(0, 1)
Kit.WindowPosition = UDim2.fromScale(0, 1)

Kit.RowHeight = 44
-- A hint given as plain text longer than this goes under the label (see the header).
Kit.InlineHintLength = 30

-- Rows with the hint underneath: how much shorter the label's line is than a plain row
-- (the hint closes up on it), the shortest that line may be, and the space under the hint.
local HINT_LIFT = 6
local MIN_LINE = 32
local HINT_BOTTOM = Theme.Space.S

export type RowProps = {
	Label: UsedAs<string>,
	-- Smaller text after the label (a requirement, a hint).
	Hint: UsedAs<string>?,
	HintColor: UsedAs<Color3>?,
	-- true: the hint under the label, wrapped, the row as tall as it takes. false: beside
	-- the label on one line. Default: true for plain text longer than Kit.InlineHintLength.
	HintBelow: boolean?,
	-- Height of the row; of its first line when the hint is underneath.
	Height: number?,
	LayoutOrder: number?,
	Visible: UsedAs<boolean>?,
	Selected: UsedAs<boolean>?,
	-- Controls, laid out from the right edge.
	Children: Fusion.Child?,
	-- Content before the label (a key cap, a swatch).
	Leading: Fusion.Child?,
}

-- The two halves of a row's line: text from the left edge, controls from the right one.
local function rowLine(scope: Scope, props: RowProps, inlineHint: boolean): { Instance }
	return {
		scope:New("Frame")({
			Name = "Left",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(Theme.Space.M, 0),
			Size = UDim2.new(1, -Theme.Space.M, 1, 0),
			[Fusion.Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, Theme.Space.S),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				props.Leading,
				UI.Label(scope, { Name = "Label", Text = props.Label, Variant = "BodyBold", LayoutOrder = 10 }),
				if inlineHint and props.Hint
					then UI.Label(scope, {
						Name = "Hint",
						Text = props.Hint,
						Variant = "Small",
						Color = props.HintColor,
						LayoutOrder = 11,
					})
					else nil,
			} :: { any },
		}),
		scope:New("Frame")({
			Name = "Right",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -Theme.Space.S, 0, 0),
			Size = UDim2.new(1, -Theme.Space.S * 2, 1, 0),
			[Fusion.Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, Theme.Space.S),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				props.Children,
			} :: { any },
		}),
	}
end

-- A full-width strip: text on the left, controls on the right.
function Kit.Row(scope: Scope, props: RowProps): Frame
	local height = props.Height or Kit.RowHeight
	local hint = props.Hint
	local below = hint ~= nil and props.HintBelow
	if hint ~= nil and props.HintBelow == nil then
		below = type(hint) == "string" and #hint > Kit.InlineHintLength
	end

	local color = scope:Computed(function(use): Color3
		return if use(props.Selected) then Theme.Colors.PrimaryDark else Theme.Colors.Raised
	end)
	local stroke = scope:Computed(function(use): Color3
		return if use(props.Selected) then Theme.Colors.Accent else Theme.Colors.Border
	end)

	if not below then
		return UI.Panel(scope, {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = props.LayoutOrder,
			Visible = props.Visible,
			Color = color,
			Stroke = stroke,
			Radius = Theme.Radius.Small,
			Gradient = false,
			Children = rowLine(scope, props, true),
		})
	end

	-- The row is as tall as its line and its description together: `height` is only the
	-- least it can be.
	return UI.Panel(scope, {
		Name = "Row",
		Size = UDim2.new(1, 0, 0, height),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		Color = color,
		Stroke = stroke,
		Radius = Theme.Radius.Small,
		Gradient = false,
		Children = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("Frame")({
				Name = "Line",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, math.max(height - HINT_LIFT, MIN_LINE)),
				LayoutOrder = 1,
				[Fusion.Children] = rowLine(scope, props, false),
			}),
			scope:New("Frame")({
				Name = "Description",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				[Fusion.Children] = {
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Space.M),
						PaddingRight = UDim.new(0, Theme.Space.M),
						PaddingBottom = UDim.new(0, HINT_BOTTOM),
					}),
					UI.Label(scope, {
						Name = "Hint",
						Text = hint :: UsedAs<string>,
						Variant = "Small",
						Color = props.HintColor,
						Wrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						-- A fixed width and a free height: a wrapping paragraph.
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
					}),
				},
			}),
		},
	})
end

export type StepperProps = {
	Text: UsedAs<string>,
	OnStep: (delta: number) -> (),
	-- Width of the value between the arrows.
	ValueWidth: number?,
	LayoutOrder: number?,
	-- Drawn between the value and the right arrow (a colour swatch).
	Children: Fusion.Child?,
}

-- "<  value  >": the arrows report -1 / +1, the screen decides what the next value is.
function Kit.Stepper(scope: Scope, props: StepperProps): Frame
	local function arrow(text: string, delta: number, order: number)
		return UI.Button(scope, {
			Name = if delta < 0 then "Previous" else "Next",
			Text = text,
			Variant = "Secondary",
			Size = UDim2.fromOffset(32, 32),
			LayoutOrder = order,
			OnClick = function()
				props.OnStep(delta)
			end,
		})
	end

	return UI.Stack(scope, {
		Name = "Stepper",
		Direction = "Horizontal",
		Gap = Theme.Space.XS,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		LayoutOrder = props.LayoutOrder,
		Children = {
			arrow("<", -1, 1),
			UI.Label(scope, {
				Name = "Value",
				Text = props.Text,
				Variant = "BodyBold",
				Size = UDim2.fromOffset(props.ValueWidth or 44, 32),
				LayoutOrder = 2,
			}),
			props.Children,
			arrow(">", 1, 4),
		} :: { any },
	})
end

-- A small square showing a colour (palette entries, dyes, auras).
function Kit.Swatch(scope: Scope, color: UsedAs<Color3>, layoutOrder: number?, visible: UsedAs<boolean>?): Frame
	return UI.Panel(scope, {
		Name = "Swatch",
		Size = UDim2.fromOffset(26, 26),
		LayoutOrder = layoutOrder,
		Visible = visible,
		Color = color,
		Radius = Theme.Radius.Small,
		Gradient = false,
	})
end

export type SectionProps = Theme.Layout & {
	Title: UsedAs<string>,
	Children: Fusion.Child?,
}

local SECTION_HEADER = 30

-- A surface with a heading; Children go in the frame under it ("Body").
function Kit.Section(scope: Scope, props: SectionProps): Frame
	return UI.Panel(
		scope,
		Theme.place(props, {
			Name = "Section",
			Padding = Theme.Space.M,
			Children = {
				UI.Label(scope, {
					Name = "Heading",
					Text = props.Title,
					Variant = "Heading",
					Color = Theme.Colors.Accent,
					TextXAlignment = Enum.TextXAlignment.Left,
					Size = UDim2.new(1, 0, 0, SECTION_HEADER),
				}),
				scope:New("Frame")({
					Name = "Body",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, SECTION_HEADER + Theme.Space.S),
					Size = UDim2.new(1, 0, 1, -(SECTION_HEADER + Theme.Space.S)),
					[Fusion.Children] = props.Children,
				}),
			},
		}) :: any
	)
end

-- The keyboard key bound to an action, kept current ("Hotkeys.<Action>.KB").
function Kit.key(scope: Scope, action: string, default: string): Fusion.Value<any>
	return Bind.data(scope, `Hotkeys.{action}.KB`, default)
end

function Kit.KeyCap(scope: Scope, text: UsedAs<string>, layoutOrder: number?): TextLabel
	return UI.Badge(scope, {
		Name = "Key",
		Text = text,
		Color = Theme.Colors.Accent,
		Soft = true,
		LayoutOrder = layoutOrder,
	})
end

local PAD_ICON = 30
-- What an action without a button shows.
local NO_BUTTON = "-"
local UNBOUND = "None"

--[[
	One gamepad button as the picture of the player's own pad: the engine hands out the
	image of a button for the platform in use (Xbox letters, PlayStation shapes, a generic
	pad), so nothing has to be guessed here (UI.Util.PadIcons). `key` is a KeyCode name and
	may be state: the picture follows it. A button the engine has no picture for shows its
	name, an unbound action ("None") a dash.
]]
function Kit.PadButton(scope: Scope, key: UsedAs<string>, layoutOrder: number?): Instance
	local image = scope:Computed(function(use): string
		return PadIcons.image(use(key))
	end)
	return scope:New("Frame")({
		Name = "PadButton",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = layoutOrder,
		[Fusion.Children] = {
			-- One of the two shows; the list only keeps the frame as large as that one.
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			UI.Image(scope, {
				Name = "Picture",
				Image = image,
				Size = UDim2.fromOffset(PAD_ICON, PAD_ICON),
				Visible = scope:Computed(function(use): boolean
					return use(image) ~= ""
				end),
			}),
			UI.Badge(scope, {
				Name = "Key",
				Text = scope:Computed(function(use): string
					local name = use(key)
					if type(name) ~= "string" or name == "" or name == UNBOUND then
						return NO_BUTTON
					end
					return (string.gsub(name, "^Button", ""))
				end),
				Color = Theme.Colors.Accent,
				Soft = true,
				Visible = scope:Computed(function(use): boolean
					return use(image) == ""
				end),
			}),
		},
	})
end

-- Several gamepad buttons pressed together (a chord), joined with "+". See Kit.PadButton.
function Kit.PadCombo(scope: Scope, keys: { UsedAs<string> }, layoutOrder: number?): Instance
	local pieces: { Instance } = {}
	for index, key in keys do
		if index > 1 then
			table.insert(
				pieces,
				UI.Label(scope, {
					Name = "Plus",
					Text = "+",
					Variant = "BodyBold",
					Color = Theme.Colors.TextMuted,
					LayoutOrder = index * 2 - 1,
				})
			)
		end
		table.insert(pieces, Kit.PadButton(scope, key, index * 2))
	end

	return UI.Stack(scope, {
		Name = "Pad",
		Direction = "Horizontal",
		Gap = Theme.Space.XS,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = layoutOrder,
		Children = pieces,
	})
end

-- Runs a Knit call whose answer nobody waits for.
function Kit.send(promise: any)
	promise:catch(warn)
end

return Kit
