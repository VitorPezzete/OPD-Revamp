--!strict
--[[
	A full-screen dim layer behind a dialog. It also swallows clicks, so nothing under
	the dialog can be pressed; OnClick (optional) is the "clicked outside" handler.

		UI.Backdrop(scope, { OnClick = context.Close })

	Use it in a screen whose ScreenGui has IgnoreGuiInset = true.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = {
	Visible: UsedAs<boolean>?,
	Transparency: UsedAs<number>?,
	OnClick: (() -> ())?,
}

return function(scope: Scope, props: Props): TextButton
	return scope:New("TextButton")({
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Theme.Colors.Backdrop,
		BackgroundTransparency = props.Transparency or Theme.Transparency.Backdrop,
		Visible = if props.Visible == nil then true else props.Visible,
		[Fusion.OnEvent("Activated")] = function()
			if props.OnClick then
				props.OnClick()
			end
		end,
	}) :: any
end
