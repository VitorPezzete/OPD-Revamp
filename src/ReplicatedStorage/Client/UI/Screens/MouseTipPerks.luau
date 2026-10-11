--!strict
--[[
	Expertise perk tooltip: the perk icon, how many points are invested out of the
	limit (as a bar) and the perk description. The expertise menu feeds it through
	Tooltip.showPerk({ Description, Value, Limit, Icon, IconColor, ProgressColor }).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MouseFollower = require(ReplicatedStorage.Client.UI.Components.MouseFollower)

type Scope = Theme.Scope

-- Shown for a perk that names no icon of its own.
local DEFAULT_ICON = "http://www.roblox.com/asset/?id=8530145081"
local WIDTH = 400
local ICON_SIZE = 72
local BAR_HEIGHT = 20

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local perk = Tooltip.Perk

		local ratio = scope:Computed(function(use): number
			local current = use(perk)
			if not current or current.Limit <= 0 then
				return 0
			end
			return math.clamp(current.Value / current.Limit, 0, 1)
		end)
		local iconColor = scope:Computed(function(use): Color3
			local current = use(perk)
			return (current and current.IconColor) or Theme.Colors.Accent
		end)
		local progressColor = scope:Computed(function(use): Color3
			local current = use(perk)
			return (current and (current.ProgressColor or current.IconColor)) or Theme.Colors.Primary
		end)

		return UI.Screen(scope, {
			Name = "MouseTipPerks",
			DisplayOrder = 100,
			Children = {
				MouseFollower(scope, {
					Name = "Tip",
					Width = WIDTH,
					Visible = scope:Computed(function(use): boolean
						return use(perk) ~= nil
					end),
					Children = {
						UI.Stack(scope, {
							Name = "Content",
							Direction = "Horizontal",
							Gap = Theme.Space.M,
							Size = UDim2.fromScale(1, 0),
							AutomaticSize = Enum.AutomaticSize.Y,
							Children = {
								UI.Image(scope, {
									Name = "PerkIcon",
									Image = scope:Computed(function(use): string
										local current = use(perk)
										return (current and current.Icon) or DEFAULT_ICON
									end),
									Color = iconColor,
									Background = Theme.Colors.Sunken,
									Radius = Theme.Radius.Small,
									Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
									LayoutOrder = 1,
								}),
								UI.Stack(scope, {
									Name = "Text",
									Size = UDim2.new(1, -(ICON_SIZE + Theme.Space.M), 0, 0),
									AutomaticSize = Enum.AutomaticSize.Y,
									Gap = Theme.Space.S,
									LayoutOrder = 2,
									Children = {
										UI.ProgressBar(scope, {
											Name = "Progress",
											Value = ratio,
											Color = progressColor,
											Text = scope:Computed(function(use): string
												local current = use(perk)
												return if current then `{current.Value} / {current.Limit}` else ""
											end),
											-- The tip jumps from perk to perk: no slide between their values.
											Animated = false,
											Size = UDim2.new(1, 0, 0, BAR_HEIGHT),
											LayoutOrder = 1,
										}),
										UI.Label(scope, {
											Name = "Description",
											Text = scope:Computed(function(use): string
												local current = use(perk)
												return if current then current.Description else ""
											end),
											Variant = "Small",
											Color = Theme.Colors.Text,
											Wrapped = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Top,
											Size = UDim2.fromScale(1, 0),
											AutomaticSize = Enum.AutomaticSize.Y,
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
