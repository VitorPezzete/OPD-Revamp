--!strict
--[[
	Generic Accept / Decline prompt (legacy ConfirmationEvent): the world event invitation,
	the crew invitation. The old invitation sheet in the upper middle of the screen, built
	by Legacy.Components.InvitePrompt.

		UIController:Open("ConfirmationEvent", {
			Text = "Participate: Marine Raid",
			OnConfirm = function() ... end,
			OnDecline = function() ... end,   -- optional
		})

	Only one prompt at a time: opening while one is up is ignored by the UIController.
	Closing it from outside (UIController:Close) runs neither callback.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local InvitePrompt = require(ReplicatedStorage.Client.UI.Legacy.Components.InvitePrompt)

type Scope = Fusion.Scope<typeof(Fusion)>

-- Over the windows, like the rework's prompt.
local DISPLAY_ORDER = 15

export type Args = {
	Text: string,
	OnConfirm: () -> (),
	OnDecline: (() -> ())?,
}

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local args: Args = if type(context.Args) == "table" then context.Args else {} :: any

		local answered = false
		-- The screen closes first, so a callback that opens another prompt finds the slot free.
		local function answer(callback: (() -> ())?)
			if answered then
				return
			end
			answered = true
			context.Close()
			if type(callback) == "function" then
				task.spawn(callback)
			end
		end

		return Kit.Screen(scope, {
			Name = "ConfirmationEvent",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				InvitePrompt(scope, {
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
