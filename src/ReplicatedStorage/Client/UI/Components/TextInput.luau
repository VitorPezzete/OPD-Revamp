--!strict
--[[
	A text box.

		local name = scope:Value("")
		UI.TextInput(scope, { Text = name, Placeholder = "Crew name", MaxLength = 20, OnSubmit = create })

	Text (a Fusion value) follows what is typed. OnSubmit fires on Enter. Numeric keeps
	digits only. The server still validates whatever is sent: this is only convenience.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Numerals = require(ReplicatedStorage.Client.UI.Util.Numerals)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Text: Fusion.Value<string>?,
	Placeholder: UsedAs<string>?,
	MaxLength: number?,
	Numeric: boolean?,
	TextSize: number?,
	TextXAlignment: Enum.TextXAlignment?,
	OnSubmit: ((text: string) -> ())?,
	OnChange: ((text: string) -> ())?,
}

return function(scope: Scope, props: Props): TextBox
	local focused = scope:Value(false)
	local box: TextBox

	local function sanitize(text: string): string
		if props.Numeric then
			text = (string.gsub(text, "%D", ""))
		end
		if props.MaxLength and utf8.len(text) and (utf8.len(text) :: number) > props.MaxLength then
			text = string.sub(text, 1, (utf8.offset(text, props.MaxLength + 1) or (#text + 1)) - 1)
		end
		return text
	end

	box = scope:New("TextBox")(Theme.place(props, {
		Name = "TextInput",
		Size = UDim2.fromOffset(240, 40),
		BackgroundColor3 = Theme.Colors.Sunken,
		BackgroundTransparency = Theme.Transparency.Sunken,
		ClearTextOnFocus = false,
		FontFace = if props.Numeric then Numerals.Font else Theme.Fonts.Body,
		Text = if props.Text then Fusion.peek(props.Text) else "",
		PlaceholderText = props.Placeholder or "",
		PlaceholderColor3 = Theme.Colors.TextDim,
		TextColor3 = Theme.Colors.Text,
		TextSize = props.TextSize or Theme.TextSize.Body,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		[Fusion.OnChange("Text")] = function(text: string)
			local clean = sanitize(text)
			if clean ~= text then
				box.Text = clean
				return
			end
			if props.Text and Fusion.peek(props.Text) ~= clean then
				props.Text:set(clean)
			end
			if props.OnChange then
				props.OnChange(clean)
			end
		end,
		[Fusion.OnEvent("Focused")] = function()
			focused:set(true)
		end,
		[Fusion.OnEvent("FocusLost")] = function(enterPressed: boolean)
			focused:set(false)
			if enterPressed and props.OnSubmit then
				props.OnSubmit(box.Text)
			end
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Small) }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = scope:Computed(function(use): Color3
					return if use(focused) then Theme.Colors.BorderStrong else Theme.Colors.Border
				end),
				Transparency = scope:Computed(function(use): number
					return if use(focused) then Theme.Stroke.StrongTransparency else Theme.Stroke.Transparency
				end),
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Space.M),
				PaddingRight = UDim.new(0, Theme.Space.M),
			}),
		},
	})) :: any

	-- The value changed from outside (cleared after sending): the box follows.
	if props.Text then
		scope:Observer(props.Text):onChange(function()
			local text = Fusion.peek(props.Text)
			if box.Text ~= text then
				box.Text = text
			end
		end)
	end

	return box
end
