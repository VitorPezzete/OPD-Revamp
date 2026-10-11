--!strict
--[[
	A button with hover / press feedback.

		UI.Button(scope, { Text = "Buy", OnClick = buy })
		UI.Button(scope, { Text = "Reset", Variant = "Danger", Disabled = busy, OnClick = reset })
		UI.Button(scope, { Icon = "rbxassetid://123", Variant = "Ghost", Size = UDim2.fromOffset(40, 40), OnClick = f })

	Variants: Primary (default, reddish brown), Secondary (a faint tint with a thin line),
	Danger, Success, Ghost (nothing but its text until hovered). Selected paints the button as the active one of a group.
	Extra content (badges, custom layouts) goes in Children.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Variant = "Primary" | "Secondary" | "Danger" | "Success" | "Ghost"

export type Props = Theme.Layout & {
	Text: UsedAs<string>?,
	Icon: UsedAs<string>?,
	IconColor: UsedAs<Color3>?,
	Variant: UsedAs<Variant>?,
	Disabled: UsedAs<boolean>?,
	Selected: UsedAs<boolean>?,
	TextSize: number?,
	TextColor: UsedAs<Color3>?,
	Radius: number?,
	OnClick: (() -> ())?,
	OnHover: ((hovering: boolean) -> ())?,
	Children: Fusion.Child?,
}

type Palette = {
	Idle: Color3,
	Hover: Color3,
	Pressed: Color3,
	Text: Color3,
	Stroke: Color3,
	IdleTransparency: number,
	HoverTransparency: number,
}

local C = Theme.Colors
local PALETTES: { [Variant]: Palette } = {
	Primary = {
		Idle = C.Primary,
		Hover = C.PrimaryHover,
		Pressed = C.PrimaryPressed,
		Text = C.TextOnPrimary,
		Stroke = C.BorderStrong,
		IdleTransparency = 0,
		HoverTransparency = 0,
	},
	Secondary = {
		Idle = C.Raised,
		Hover = C.Hover,
		Pressed = C.Surface,
		Text = C.Text,
		Stroke = C.Border,
		IdleTransparency = Theme.Transparency.Control,
		HoverTransparency = 0,
	},
	Danger = {
		Idle = Color3.fromRGB(138, 44, 34),
		Hover = Color3.fromRGB(160, 56, 44),
		Pressed = Color3.fromRGB(110, 34, 26),
		Text = C.Text,
		Stroke = C.Danger,
		IdleTransparency = 0,
		HoverTransparency = 0,
	},
	Success = {
		Idle = Color3.fromRGB(70, 96, 46),
		Hover = Color3.fromRGB(86, 116, 58),
		Pressed = Color3.fromRGB(54, 76, 36),
		Text = C.Text,
		Stroke = C.Success,
		IdleTransparency = 0,
		HoverTransparency = 0,
	},
	Ghost = {
		Idle = C.Raised,
		Hover = C.Hover,
		Pressed = C.Surface,
		Text = C.TextMuted,
		Stroke = C.Border,
		IdleTransparency = 1,
		HoverTransparency = 0,
	},
}

return function(scope: Scope, props: Props): TextButton
	local hovering = scope:Value(false)
	local pressed = scope:Value(false)

	local function palette(use: Fusion.Use): Palette
		return PALETTES[(use(props.Variant) or "Primary") :: Variant]
	end
	local function isDisabled(use: Fusion.Use): boolean
		return use(props.Disabled) == true
	end

	local background = scope:Spring(
		scope:Computed(function(use): Color3
			local colors = palette(use)
			if isDisabled(use) then
				return C.Sunken
			elseif use(props.Selected) then
				return C.PrimaryDark
			elseif use(pressed) then
				return colors.Pressed
			elseif use(hovering) then
				return colors.Hover
			end
			return colors.Idle
		end),
		Theme.Motion.Speed,
		Theme.Motion.Damping
	)
	local transparency = scope:Spring(
		scope:Computed(function(use): number
			if isDisabled(use) then
				return 0.75
			elseif use(props.Selected) then
				return 0
			elseif use(hovering) or use(pressed) then
				return palette(use).HoverTransparency
			end
			return palette(use).IdleTransparency
		end),
		Theme.Motion.Speed,
		Theme.Motion.Damping
	)
	local textColor = scope:Computed(function(use): Color3
		if isDisabled(use) then
			return C.TextDim
		elseif use(props.Selected) then
			return C.Text
		end
		return use(props.TextColor) or palette(use).Text
	end)
	local hasIcon = props.Icon ~= nil
	local hasText = props.Text ~= nil

	return scope:New("TextButton")(Theme.place(props, {
		Name = "Button",
		Size = UDim2.fromOffset(160, 44),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = background,
		BackgroundTransparency = transparency,
		Active = scope:Computed(function(use)
			return not isDisabled(use)
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
			pressed:set(false)
			if props.OnHover then
				props.OnHover(false)
			end
		end,
		[Fusion.OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
		end,
		[Fusion.OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
		end,
		[Fusion.Children] = {
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = scope:Computed(function(use): Color3
					return if use(props.Selected) then C.BorderStrong else palette(use).Stroke
				end),
				Transparency = scope:Computed(function(use): number
					if isDisabled(use) then
						return 0.8
					elseif use(props.Selected) then
						return Theme.Stroke.StrongTransparency
					end
					return if palette(use).IdleTransparency == 1 then 1 else Theme.Stroke.Transparency
				end),
			}),
			scope:New("Frame")({
				Name = "Content",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				[Fusion.Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, Theme.Space.S),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					if hasIcon
						then scope:New("ImageLabel")({
							Name = "Icon",
							BackgroundTransparency = 1,
							LayoutOrder = 1,
							Size = if hasText then UDim2.fromOffset(22, 22) else UDim2.fromScale(0.62, 0.62),
							SizeConstraint = if hasText
								then Enum.SizeConstraint.RelativeXY
								else Enum.SizeConstraint.RelativeYY,
							ScaleType = Enum.ScaleType.Fit,
							Image = props.Icon,
							ImageColor3 = props.IconColor or textColor,
						})
						else nil,
					if hasText
						then scope:New("TextLabel")({
							Name = "Label",
							BackgroundTransparency = 1,
							LayoutOrder = 2,
							AutomaticSize = Enum.AutomaticSize.XY,
							FontFace = Theme.Fonts.Heading,
							RichText = true,
							Text = scope:Computed(function(use): string
								return Numerals.rich(use(props.Text) or "", false)
							end),
							TextColor3 = textColor,
							TextSize = props.TextSize or Theme.TextSize.Body,
						})
						else nil,
				} :: { any },
			}),
			props.Children,
		} :: { any },
	})) :: any
end
