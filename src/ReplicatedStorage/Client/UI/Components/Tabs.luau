--!strict
--[[
	A row (or column) of buttons where one is selected.

		local tab = scope:Value("Weapons")
		UI.Tabs(scope, {
			Tabs = { { Key = "Weapons", Text = "Weapons" }, { Key = "Fruits", Text = "Fruits" } },
			Selected = tab,
		})

	Clicking sets Selected; OnSelect (optional) runs after it. The content of each tab is
	the screen's business: show it with a Computed on Selected.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Button = require(script.Parent.Button)

type Scope = Theme.Scope

export type Tab = { Key: string, Text: string, Icon: string? }

export type Props = Theme.Layout & {
	Tabs: { Tab },
	Selected: Fusion.Value<any>,
	OnSelect: ((key: string) -> ())?,
	Direction: ("Horizontal" | "Vertical")?,
	TabSize: UDim2?,
	Gap: number?,
}

return function(scope: Scope, props: Props): Frame
	local horizontal = props.Direction ~= "Vertical"
	local buttons: { any } = {}

	for index, tab in props.Tabs do
		table.insert(
			buttons,
			Button(scope, {
				Name = tab.Key,
				Text = tab.Text,
				Icon = tab.Icon,
				Variant = "Secondary",
				LayoutOrder = index,
				Size = props.TabSize or UDim2.fromOffset(140, 40),
				Selected = scope:Computed(function(use)
					return use(props.Selected) == tab.Key
				end),
				OnClick = function()
					props.Selected:set(tab.Key)
					if props.OnSelect then
						props.OnSelect(tab.Key)
					end
				end,
			})
		)
	end

	return scope:New("Frame")(Theme.place(props, {
		Name = "Tabs",
		BackgroundTransparency = 1,
		AutomaticSize = if props.Size then Enum.AutomaticSize.None else Enum.AutomaticSize.XY,
		[Fusion.Children] = {
			scope:New("UIListLayout")({
				FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
				Padding = UDim.new(0, props.Gap or Theme.Space.S),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			buttons,
		} :: { any },
	})) :: any
end
