--!strict
--[[
	Dialogue with Silvers Rayleigh, the Haki master.

	Strong enough and without Haki: three lines of dialogue, then HakiQuestService.Unlock.
	Everything shown here is cosmetic; the server re-checks the levels and that the
	player is standing next to him.

	He only exists in Workspace.Map.Merchants while he is around (the server parks the model
	elsewhere the rest of the time); UIController binds merchants as they appear.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local QuestConfig = require(ReplicatedStorage.Shared.Configs.QuestConfig)
local Dialogue = require(ReplicatedStorage.Client.UI.Components.Dialogue)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local SCREEN = "QuestHaki"
local HAKI = QuestConfig.Haki
local LINES = HAKI.Dialogue
local PORTRAIT = "rbxassetid://2776110574"

return {
	Merchants = { HAKI.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		MerchantDialogue.closeOnMove(scope, context.Close)

		local skills = Knit.GetController("DataController"):Get("Skills") or {}
		local function level(skill: string): number
			return (skills[skill] and skills[skill].Level) or 0
		end
		local strong = level("Melee") + level("Sniper") + level("Defense") + level("Sword") >= HAKI.TotalLevelRequirement
		local canLearn = strong and level("Haki") == 0

		local text = scope:Value(if canLearn then LINES.Greeting elseif strong then LINES.Trained else LINES.Stranger)
		local buttonText = scope:Value(if strong and not canLearn then "Okay" else "Next")

		local step = 0
		local function advance()
			if not canLearn then
				context.Close()
				return
			end

			step += 1
			if step == 1 then
				text:set(LINES.Offer)
				buttonText:set("Accept")
			elseif step == 2 then
				text:set(LINES.Lesson)
			else
				context.Close()
				Knit.GetService("HakiQuestService"):Unlock():catch(warn)
			end
		end

		return UI.Screen(scope, {
			Name = SCREEN,
			DisplayOrder = 10,
			Children = {
				Dialogue(scope, {
					Title = "Haki Master",
					Speaker = "Silvers Rayleigh",
					Portrait = PORTRAIT,
					Text = text,
					Size = UDim2.fromOffset(760, 300),
					Actions = {
						UI.Button(scope, {
							Name = "Accept",
							Text = buttonText,
							Size = UDim2.fromOffset(160, 40),
							OnClick = advance,
						}),
					},
				}),
			},
		})
	end,
}
