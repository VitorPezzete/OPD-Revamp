--!strict
--[[
	Respec tooltip: what resetting the invested expertise points costs. Shown with
	Tooltip.showPerkPoints() / hidePerkPoints() by the respec button.

	The price shown is display only: 2,000 Beri per invested point. The server computes
	the real price when the respec is requested.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MouseFollower = require(ReplicatedStorage.Client.UI.Components.MouseFollower)

type Scope = Theme.Scope

local BERI_PER_POINT = 2000
-- The expertise point star.
local POINTS_ICON = "rbxassetid://2204238988"
local ICON_SIZE = 40

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local perks = Bind.data(scope, "Expertise.Perks", {})

		local invested = scope:Computed(function(use): number
			local total = 0
			for _, perk in use(perks) :: { [string]: any } do
				if type(perk) == "table" and type(perk.Value) == "number" then
					total += perk.Value
				end
			end
			return total
		end)

		return UI.Screen(scope, {
			Name = "MouseTipPerkPoints",
			DisplayOrder = 100,
			Children = {
				MouseFollower(scope, {
					Name = "Tip",
					Visible = Tooltip.PerkPoints,
					Children = {
						UI.Stack(scope, {
							Name = "Content",
							Direction = "Horizontal",
							Gap = Theme.Space.M,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Children = {
								UI.Image(scope, {
									Name = "Points",
									Image = POINTS_ICON,
									Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
									LayoutOrder = 1,
								}),
								UI.Stack(scope, {
									Name = "Text",
									Gap = Theme.Space.XS,
									LayoutOrder = 2,
									Children = {
										UI.Label(scope, {
											Name = "Heading",
											Text = scope:Computed(function(use): string
												local points = use(invested)
												return if points > 0
													then `Respec cost ({Bind.formatNumber(points)} points invested)`
													else "Respec"
											end),
											Variant = "Tiny",
											Color = Theme.Colors.TextMuted,
											LayoutOrder = 1,
										}),
										UI.Label(scope, {
											Name = "Description",
											Text = scope:Computed(function(use): string
												local points = use(invested)
												return if points > 0
													then `${Bind.formatNumber(points * BERI_PER_POINT)}`
													else "No Points Invested"
											end),
											Variant = "Heading",
											Color = scope:Computed(function(use): Color3
												return if use(invested) > 0 then Theme.Colors.Beri else Theme.Colors.Warning
											end),
											LayoutOrder = 2,
										}),
									},
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
