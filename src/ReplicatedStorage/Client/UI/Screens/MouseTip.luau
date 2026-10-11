--!strict
--[[
	Plain text tooltip that follows the mouse. Driven by UI.Util.Tooltip: other screens
	call Tooltip.show(text) / Tooltip.hide() instead of reaching into this gui.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Client.UI.Theme)
local Tooltip = require(ReplicatedStorage.Client.UI.Util.Tooltip)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MouseFollower = require(ReplicatedStorage.Client.UI.Components.MouseFollower)

type Scope = Theme.Scope

local MAX_WIDTH = 420

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local label = UI.Label(scope, {
			Name = "Message",
			Text = scope:Computed(function(use): string
				return use(Tooltip.Text) or ""
			end),
			Variant = "Small",
			Color = Theme.Colors.Text,
			Wrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- Long tips wrap instead of growing sideways.
		scope:New("UISizeConstraint")({
			MaxSize = Vector2.new(MAX_WIDTH, math.huge),
			Parent = label,
		})

		return UI.Screen(scope, {
			Name = "MouseTip",
			DisplayOrder = 100,
			Children = {
				MouseFollower(scope, {
					Name = "Tip",
					Padding = Theme.Space.S,
					Visible = scope:Computed(function(use): boolean
						return use(Tooltip.Text) ~= nil
					end),
					Children = { label },
				}),
			},
		})
	end,
}
