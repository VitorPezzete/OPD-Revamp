--!strict
--[[
	Generic Accept / Decline prompt (the world event invitation, the crew invitation).

		UIController:Open("ConfirmationEvent", {
			Text = "Participate: Marine Raid",
			OnConfirm = function() ... end,
			OnDecline = function() ... end,   -- optional
		})

	Only one prompt at a time: opening while one is up is ignored by the UIController.
	Closing it from outside (UIController:Close) runs neither callback.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InvitePrompt = require(ReplicatedStorage.Client.UI.Components.InvitePrompt)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

export type Args = {
	Text: string,
	OnConfirm: () -> (),
	OnDecline: (() -> ())?,
}

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local args: Args = if type(context.Args) == "table" then context.Args else {} :: any

		-- The screen closes first, so a callback that opens another prompt finds the slot free.
		local function answer(callback: (() -> ())?)
			context.Close()
			if type(callback) == "function" then
				task.spawn(callback)
			end
		end

		return UI.Screen(scope, {
			Name = "ConfirmationEvent",
			DisplayOrder = 15,
			Children = {
				InvitePrompt(scope, {
					Name = "InviteFrame",
					Title = "Invitation",
					Text = if type(args.Text) == "string" then args.Text else "",
					OnAccept = function()
						answer(args.OnConfirm)
					end,
					OnDecline = function()
						answer(args.OnDecline)
					end,
				}),
			},
		})
	end,
}
