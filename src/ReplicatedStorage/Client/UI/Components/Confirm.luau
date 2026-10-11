--!strict
--[[
	A small dialog with a message and two buttons. Returned as a Window: put it in a
	screen (usually over a UI.Backdrop) and control it with Visible.

		UI.Confirm(scope, {
			Title = "Reset stats",
			Message = "This costs 500 gems. Continue?",
			ConfirmText = "Reset",   Danger = true,
			OnConfirm = reset,       OnCancel = context.Close,
		})
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Button = require(script.Parent.Button)
local Label = require(script.Parent.Label)
local Window = require(script.Parent.Window)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Title: UsedAs<string>,
	Message: UsedAs<string>,
	ConfirmText: UsedAs<string>?,
	CancelText: UsedAs<string>?,
	Danger: boolean?,
	Busy: UsedAs<boolean>?,
	OnConfirm: () -> (),
	OnCancel: () -> (),
}

local BUTTON_HEIGHT = 46

return function(scope: Scope, props: Props): Frame
	return Window(scope, {
		Name = props.Name or "Confirm",
		Title = props.Title,
		Size = props.Size or UDim2.fromOffset(480, 260),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		OnClose = props.OnCancel,
		Children = {
			Label(scope, {
				Name = "Message",
				Text = props.Message,
				Variant = "Muted",
				Wrapped = true,
				RichText = true,
				Size = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT + Theme.Space.M)),
			}),
			Button(scope, {
				Name = "Cancel",
				Text = props.CancelText or "Cancel",
				Variant = "Secondary",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
				OnClick = props.OnCancel,
			}),
			Button(scope, {
				Name = "Confirm",
				Text = props.ConfirmText or "Confirm",
				Variant = if props.Danger then "Danger" else "Primary",
				Disabled = props.Busy,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
				OnClick = props.OnConfirm,
			}),
		},
	})
end
