--!strict
--[[
	"This will set all stats back to default" dialog, opened from the settings tab with
	UIController:Toggle("ResetStats").

	Reset asks the server and closes; what is wiped (and what it costs) is decided by
	StatResetService.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local sent = scope:Value(false)

		return UI.Screen(scope, {
			Name = "ResetStats",
			DisplayOrder = 30,
			IgnoreGuiInset = true,
			Children = {
				UI.Backdrop(scope, { OnClick = context.Close }),
				UI.Confirm(scope, {
					Title = "Reset stats",
					Message = "This cannot be undone. Your combat stats, Haki, Beri, bounty, kills and fish go back to zero, and your devil fruits and items are removed. Gems, expertise and accessories are kept.",
					ConfirmText = "Reset",
					CancelText = "Close",
					Danger = true,
					Busy = sent,
					OnCancel = context.Close,
					OnConfirm = function()
						sent:set(true)
						Knit.GetService("StatResetService"):Reset():catch(warn)
						context.Close()
					end,
				}),
			},
		})
	end,
}
