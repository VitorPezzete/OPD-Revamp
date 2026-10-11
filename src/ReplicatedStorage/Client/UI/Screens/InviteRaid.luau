--!strict
--[[
	Raid invitation. Opened by RaidController when the server announces one:
	context.Args = { Owner = string, Quest = string }; RaidController also closes it when
	the invitation runs out. The answer is a boolean: the server knows which invitation it
	is about.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local InvitePrompt = require(ReplicatedStorage.Client.UI.Components.InvitePrompt)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local RaidController = Knit.GetController("RaidController")
		local args = if type(context.Args) == "table" then context.Args else {}

		local quest = LegendaryConfig.Quests[args.Quest]
		local raidName = if quest then (string.gsub(quest.Title, "^Fight ", "")) else tostring(args.Quest)

		return UI.Screen(scope, {
			Name = "InviteRaid",
			DisplayOrder = 15,
			Children = {
				InvitePrompt(scope, {
					Name = "InviteFrame",
					Title = "Raid invitation",
					Text = `Invite from {tostring(args.Owner)} to {raidName}`,
					OnAccept = function()
						RaidController:Respond(true)
					end,
					OnDecline = function()
						RaidController:Respond(false)
					end,
				}),
			},
		})
	end,
}
