--!strict
--[[
	The invitation of the old game (InviteRaid, ConfirmationEvent): a burnt sheet in the
	upper middle of the screen with one line of text in a dark box, Accept in green and
	Decline in red under it. The player keeps playing while it is up, so nothing is
	drawn behind it and it is not a window for the gamepad.

		InvitePrompt(scope, { Text = "Invite from X to Y", OnAccept = accept, OnDecline = decline })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Name: string?,
	Text: Fusion.UsedAs<string>,
	OnAccept: () -> (),
	OnDecline: () -> (),
}

-- The old sheet on a 1920x1080 screen: 576 wide, its centre a fifth of the way down.
local SIZE = Vector2.new(580, 200)
local CENTRE = UDim2.fromScale(0.5, 0.2162)
local BUTTON_SIZE = UDim2.fromOffset(180, 52)

return function(scope: Scope, props: Props): Instance
	local buttonsHeight = BUTTON_SIZE.Y.Offset
	return Kit.Panel(scope, {
		Name = props.Name or "InviteFrame",
		Image = Kit.Images.Sheet,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = CENTRE,
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		Padding = Kit.Space.L,
		Children = {
			Kit.Well(scope, {
				Name = "InviteText",
				Transparency = 0.4,
				Size = UDim2.new(1, 0, 1, -(buttonsHeight + Kit.Space.M)),
				Padding = Kit.Space.S,
				Children = {
					Kit.Label(scope, {
						Text = props.Text,
						TextSize = Kit.TextSize.Heading,
						Fit = true,
						Size = UDim2.fromScale(1, 1),
					}),
				},
			}),
			Kit.Stack(scope, {
				Name = "Buttons",
				Direction = "Horizontal",
				Gap = Kit.Space.XL,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, buttonsHeight),
				Children = {
					Kit.Button(scope, {
						Name = "AcceptButton",
						Text = "Accept",
						Variant = "Green",
						Size = BUTTON_SIZE,
						LayoutOrder = 1,
						OnClick = props.OnAccept,
					}),
					Kit.Button(scope, {
						Name = "DeclineButton",
						Text = "Decline",
						Variant = "Red",
						Size = BUTTON_SIZE,
						LayoutOrder = 2,
						OnClick = props.OnDecline,
					}),
				},
			}),
		},
	})
end
