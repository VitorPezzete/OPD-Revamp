--!strict
--[[
	Trade invitation. Opened by TradeController when the server announces one:
	context.Args = { From = Player, Seconds = number }; TradeController also closes it when
	the invitation is answered, withdrawn or runs out. The answer is a boolean: the server
	knows which invitation it is about.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local InvitePrompt = require(ReplicatedStorage.Client.UI.Components.InvitePrompt)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local TradeController = Knit.GetController("TradeController")
		local args = if type(context.Args) == "table" then context.Args else {}

		local from = args.From
		local name = if typeof(from) == "Instance" and from:IsA("Player") then from.DisplayName else "Someone"

		return UI.Screen(scope, {
			Name = "TradeInvite",
			DisplayOrder = 15,
			Children = {
				InvitePrompt(scope, {
					Name = "InviteFrame",
					Title = "Trade request",
					Text = `{name} wants to trade`,
					OnAccept = function()
						TradeController:Respond(true)
					end,
					OnDecline = function()
						TradeController:Respond(false)
					end,
				}),
			},
		})
	end,
}
