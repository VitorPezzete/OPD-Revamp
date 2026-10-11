--!strict
--[[
	A price in Gems as the old game wrote it: the number in light blue with the gem
	picture after it. Wraps its content, so it sits in a Kit.Stack next to its button.

		GemPrice.new(scope, { Text = "2.500" })
		GemPrice.new(scope, { Text = cost, TextSize = Kit.TextSize.Body })
		GemPrice.Icon, GemPrice.Color     -- for a price written on a button
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = Kit.Layout & {
	Text: Fusion.UsedAs<string>,
	TextSize: number?,
}

local GEM_ICON = "rbxassetid://1954296071"
-- The light blue of the old GemDisplayLabel.
local GEM_COLOR = Color3.fromRGB(85, 255, 255)

local GemPrice = {}

GemPrice.Icon = GEM_ICON
GemPrice.Color = GEM_COLOR

function GemPrice.new(scope: Scope, props: Props): Instance
	local size = props.TextSize or Kit.TextSize.Heading
	-- The picture a little taller than the digits, as it was.
	local icon = size + 8
	return Kit.Stack(
		scope,
		Kit.place(props, {
			Name = "GemPrice",
			Direction = "Horizontal",
			Gap = Kit.Space.XS,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Children = {
				Kit.Label(scope, {
					Name = "GemDisplayLabel",
					Text = props.Text,
					TextSize = size,
					Color = GEM_COLOR,
					LayoutOrder = 1,
				}),
				Kit.Image(scope, {
					Name = "Gem",
					Image = GEM_ICON,
					Size = UDim2.fromOffset(icon, icon),
					LayoutOrder = 2,
				}),
			},
		}) :: any
	)
end

return GemPrice
