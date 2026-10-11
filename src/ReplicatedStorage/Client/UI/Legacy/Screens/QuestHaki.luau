--!strict
--[[
	Dialogue with Silvers Rayleigh, the Haki master (legacy QuestHaki): the old purple
	dialogue window, "Haki Master" across the top, what he says in the dark box at the
	left with the answer button under it, his picture and name at the right.

	Strong enough and without Haki: three lines of dialogue, then HakiQuestService.Unlock.
	Everything shown here is cosmetic; the server re-checks the levels and that the
	player is standing next to him.

	He only exists in Workspace.Map.Merchants while he is around (the server parks the model
	elsewhere the rest of the time). The usual `Merchants = {...}` binding covers that:
	UIController binds every merchant model, the ones that appear later included, and
	opens the screen with context.Args.Merchant.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local QuestConfig = require(ReplicatedStorage.Shared.Configs.QuestConfig)
local DialogueBox = require(ReplicatedStorage.Client.UI.Legacy.Components.DialogueBox)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)

type Scope = Fusion.Scope<typeof(Fusion)>

local SCREEN = "QuestHaki"
local HAKI = QuestConfig.Haki
local LINES = HAKI.Dialogue
local DISPLAY_ORDER = 10

local OUTER_COLOR = Color3.fromRGB(113, 114, 221)
local INNER_COLOR = Color3.fromRGB(46, 5, 80)
local PORTRAIT = "rbxassetid://2776110574"

local SIDE_WIDTH = 280
local BUTTON_SIZE = UDim2.fromOffset(340, 64)

return {
	Merchants = { HAKI.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		-- Closes when the player walks away, dies or has no character.
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

		local speechWidth = -(SIDE_WIDTH + Kit.Space.XL)
		local buttonRow = BUTTON_SIZE.Y.Offset + Kit.Space.L

		return Kit.Screen(scope, {
			Name = SCREEN,
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				-- A window for the gamepad; like the rework's dialogue it has no close button.
				DialogueBox.new(scope, {
					Title = "Haki Master",
					Color = OUTER_COLOR,
					InnerColor = INNER_COLOR,
					Children = {
						DialogueBox.speech(scope, {
							Text = text,
							Size = UDim2.new(1, speechWidth, 1, -buttonRow),
						}),
						Kit.Button(scope, {
							Name = "Accept",
							Text = buttonText,
							Variant = "Blue",
							TextSize = Kit.TextSize.Heading,
							AnchorPoint = Vector2.new(0.5, 1),
							-- Under the middle of the speech box.
							Position = UDim2.new(0.5, speechWidth / 2, 1, 0),
							Size = BUTTON_SIZE,
							OnClick = advance,
						}),
						DialogueBox.portrait(scope, {
							Image = PORTRAIT,
							Speaker = "Silvers Rayleigh",
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(1, -SIDE_WIDTH / 2, 0.5, 0),
						}),
					},
				}),
			},
		})
	end,
}
