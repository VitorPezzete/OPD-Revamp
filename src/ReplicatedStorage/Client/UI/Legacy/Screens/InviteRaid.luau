--!strict
--[[
	Raid invitation prompt (legacy InviteRaid): the old invitation sheet in the upper
	middle of the screen, "Invite from <owner> to <raid>" over Accept and Decline.

	Opened by RaidController when the server announces an invitation: context.Args =
	{ Owner = string, Quest = string }; RaidController also closes it when the invitation
	runs out. The answer is a boolean: the server knows which invitation it is about.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local InvitePrompt = require(ReplicatedStorage.Client.UI.Legacy.Components.InvitePrompt)

type Scope = Fusion.Scope<typeof(Fusion)>

-- Over the windows, like the rework's prompt.
local DISPLAY_ORDER = 15

return {
	Mount = function(scope: Scope, _gui: any, context: any)
		local RaidController = Knit.GetController("RaidController")
		local args = if type(context.Args) == "table" then context.Args else {}

		local quest = LegendaryConfig.Quests[args.Quest]
		local raidName = if quest then (string.gsub(quest.Title, "^Fight ", "")) else tostring(args.Quest)

		return Kit.Screen(scope, {
			Name = "InviteRaid",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				InvitePrompt(scope, {
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
