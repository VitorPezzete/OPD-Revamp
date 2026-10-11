--!strict
--[[
	An invitation shown over the world, upper centre: one line of text, Accept and
	Decline. The player keeps playing while it is up, so there is no backdrop.

		InvitePrompt(scope, {
			Title = "Raid invitation",
			Text = "Invite from Luffy to Marine Raid",
			OnAccept = accept,
			OnDecline = decline,
		})

	Both buttons go dead after the first answer. Not part of Components/init: require it
	by its path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Button = require(script.Parent.Button)
local Label = require(script.Parent.Label)
local Panel = require(script.Parent.Panel)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

export type Props = Theme.Layout & {
	Title: UsedAs<string>,
	Text: UsedAs<string>,
	AcceptText: string?,
	DeclineText: string?,
	OnAccept: () -> (),
	OnDecline: () -> (),
}

local WIDTH = 520
local HEIGHT = 190
local BUTTON_HEIGHT = 46
local TITLE_HEIGHT = 24
-- Below the health / haki bars of the HUD.
local TOP_MARGIN = 170

return function(scope: Scope, props: Props): Frame
	local answered = scope:Value(false)

	local function answer(callback: () -> ())
		if Fusion.peek(answered) then
			return
		end
		answered:set(true)
		callback()
	end

	return Panel(scope, {
		Name = props.Name or "InvitePrompt",
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		Position = props.Position or UDim2.new(0.5, 0, 0, TOP_MARGIN),
		Size = props.Size or UDim2.fromOffset(WIDTH, HEIGHT),
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		Color = Theme.Colors.Background,
		Transparency = Theme.Transparency.Hud,
		Stroke = Theme.Colors.BorderStrong,
		Radius = Theme.Radius.Large,
		Padding = Theme.Space.L,
		Children = {
			Label(scope, {
				Name = "Title",
				Text = props.Title,
				Variant = "Small",
				Color = Theme.Colors.Accent,
				Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
			}),
			Label(scope, {
				Name = "Text",
				Text = props.Text,
				Variant = "Heading",
				Scaled = true,
				Position = UDim2.fromOffset(0, TITLE_HEIGHT + Theme.Space.XS),
				Size = UDim2.new(1, 0, 1, -(TITLE_HEIGHT + BUTTON_HEIGHT + Theme.Space.XS + Theme.Space.M)),
			}),
			Button(scope, {
				Name = "Decline",
				Text = props.DeclineText or "Decline",
				Variant = "Secondary",
				Disabled = answered,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
				OnClick = function()
					answer(props.OnDecline)
				end,
			}),
			Button(scope, {
				Name = "Accept",
				Text = props.AcceptText or "Accept",
				Variant = "Success",
				Disabled = answered,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
				OnClick = function()
					answer(props.OnAccept)
				end,
			}),
		},
	})
end
