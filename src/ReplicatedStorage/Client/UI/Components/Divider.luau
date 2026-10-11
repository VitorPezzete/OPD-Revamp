--!strict
--[[
	A thin line between groups of content.

		UI.Divider(scope, { LayoutOrder = 2 })                 -- horizontal, full width
		UI.Divider(scope, { Vertical = true, LayoutOrder = 2 })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Client.UI.Theme)

type Scope = Theme.Scope

export type Props = Theme.Layout & {
	Vertical: boolean?,
}

return function(scope: Scope, props: Props): Frame
	return scope:New("Frame")(Theme.place(props, {
		Name = "Divider",
		Size = if props.Vertical then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Colors.Border,
		BackgroundTransparency = Theme.Stroke.Transparency,
	})) :: any
end
