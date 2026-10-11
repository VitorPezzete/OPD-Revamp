--!strict
--[[
	"Sam's Quest Progress Bonus!" line shown every time a stage of an Expertise mission is
	finished: it stays three seconds and fades. Several in a row stack under each other.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local Transient = require(ReplicatedStorage.Client.UI.Components.Transient)

type Scope = Theme.Scope

local TEXT = "Sam's Quest Progress Bonus!"
local HOLD_TIME = 3
local MAX_ALERTS = 4

return {
	Persistent = true,

	Mount = function(scope: Scope, _gui: any, _context: any)
		local alerts = Transient.list(scope, MAX_ALERTS) :: Transient.List<string>

		local connection = Knit.GetService("ExpertiseService").StageCompleted:Connect(function()
			alerts.Push(TEXT, HOLD_TIME)
		end)
		table.insert(scope, function()
			connection:Disconnect()
		end)

		return UI.Screen(scope, {
			Name = "ExpertiseBonusAlert",
			DisplayOrder = 40,
			Children = {
				UI.Stack(scope, {
					Name = "Alerts",
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.4),
					Gap = Theme.Space.XS,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Children = scope:ForValues(alerts.Items, function(_use, rowScope: any, entry: Transient.Entry<string>)
						local fade = Transient.fade(rowScope, entry.Seconds, function()
							alerts.Remove(entry)
						end)
						return UI.Label(rowScope, {
							Name = "Alert",
							Text = entry.Data,
							Variant = "Heading",
							Color = Theme.Colors.Warning,
							Outline = true,
							Transparency = fade,
							LayoutOrder = entry.Id,
						})
					end),
				}),
			},
		})
	end,
}
