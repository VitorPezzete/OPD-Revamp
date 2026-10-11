--!strict
--[[
	A button of the touch controls: a see-through black disc with a white pictogram (or a
	short word when there is none), made to sit over the game without covering it.

		UI.TouchButton(scope, {
			Name = "Lock",
			Icon = "rbxassetid://123",      -- or Text = "Dash"
			Size = UDim2.fromOffset(64, 64),
			Selected = locked,              -- lit while on
			ActiveColor = Color3.new(1, 0, 0),
			OnClick = function() end,
		})

	Always round, whatever its size. Selected lights the disc with ActiveColor (white when
	none is given); Disabled dims it and ignores presses.

	OnClick is the engine's click (a touch that ends on the button). OnDown and OnUp report
	the touch itself - the finger landing on the button and leaving it - with its
	InputObject, for the buttons whose behaviour depends on more than a click
	(UI.Util.TouchControls).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local TouchLayout = require(ReplicatedStorage.Client.UI.Util.TouchLayout)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Icon: string?,
	Text: UsedAs<string>?,
	Selected: UsedAs<boolean>?,
	Disabled: boolean?,
	ActiveColor: Color3?,
	OnClick: (() -> ())?,
	OnDown: ((input: InputObject) -> ())?,
	OnUp: ((input: InputObject) -> ())?,
}

-- The look shared by everything round on the touch controls (the ability discs too).
local TouchButton = TouchLayout.Disc

local ICON_SHARE = 0.56
local TEXT_SHARE = 0.78
local DISABLED_TRANSPARENCY = 0.6

return function(scope: Scope, props: Props): TextButton
	local pressed = scope:Value(false)
	local selected = props.Selected or false
	local disabled = props.Disabled == true
	local activeColor = props.ActiveColor or TouchButton.LineColor
	local contentTransparency = if disabled then DISABLED_TRANSPARENCY else 0

	return scope:New("TextButton")(Theme.place(props, {
		Name = "TouchButton",
		Text = "",
		AutoButtonColor = false,
		Active = not disabled,
		Selectable = false,
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(selected) then activeColor:Lerp(TouchButton.Color, 0.35) else TouchButton.Color
		end),
		BackgroundTransparency = scope:Computed(function(use): number
			if use(selected) then
				return TouchButton.SelectedTransparency
			end
			return if use(pressed) then TouchButton.PressedTransparency else TouchButton.Transparency
		end),
		BorderSizePixel = 0,
		[Fusion.OnEvent("InputBegan")] = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed:set(true)
				if not disabled and props.OnDown then
					props.OnDown(input)
				end
			end
		end,
		[Fusion.OnEvent("InputEnded")] = function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressed:set(false)
				if not disabled and props.OnUp then
					props.OnUp(input)
				end
			end
		end,
		[Fusion.OnEvent("Activated")] = function()
			if not disabled and props.OnClick then
				props.OnClick()
			end
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 1 }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = 1.5,
				Color = scope:Computed(function(use): Color3
					return if use(selected) then activeColor:Lerp(TouchButton.LineColor, 0.5) else TouchButton.LineColor
				end),
				Transparency = scope:Computed(function(use): number
					return if use(selected) then 0.1 else TouchButton.LineTransparency
				end),
			}),
			if props.Icon
				then scope:New("ImageLabel")({
					Name = "Icon",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(ICON_SHARE, ICON_SHARE),
					BackgroundTransparency = 1,
					Image = props.Icon,
					ImageTransparency = contentTransparency,
					ScaleType = Enum.ScaleType.Fit,
				})
				else scope:New("TextLabel")({
					Name = "Caption",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(TEXT_SHARE, 0.34),
					BackgroundTransparency = 1,
					Text = props.Text or "",
					FontFace = Numerals.Plain,
					TextScaled = true,
					TextColor3 = Color3.new(1, 1, 1),
					TextTransparency = contentTransparency,
				}),
		} :: { any },
	})) :: any
end
