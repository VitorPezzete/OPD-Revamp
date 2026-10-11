--!strict
--[[
	The Legendary Hero's quest board.

	Picking a quest shows the hero's line for the player's situation: on cooldown, not
	qualified, already holding the compass, first raid, or qualified. The line is chosen
	from the replicated data with the predicates of LegendaryConfig, the same ones the
	server enforces when Accept is pressed; the server's answer replaces the line when it
	disagrees. Walking away closes the board (RaidController closes it too when a lobby
	opens).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local CompassConfig = require(ReplicatedStorage.Shared.Configs.CompassConfig)
local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

-- The board: order, short name, party size and picture of each quest of LegendaryConfig.
local BOARD: { { Quest: string, Title: string, Party: string, Image: string } } = {
	{ Quest = "MarineRaid", Title = "Marine Raid", Party = "1-4 Players", Image = "rbxassetid://77909306485141" },
	{ Quest = "Endless", Title = "Endless", Party = "1-4 Players", Image = "rbxassetid://113491974530196" },
	{ Quest = "FireBoss", Title = "Fire Boss", Party = "1 Player", Image = "rbxassetid://134273497267016" },
}
local GEM_ICON = "rbxassetid://1954296071"

-- Server answer -> dialogue set of the quest (falls back to NotQualified).
local RESULT_LINES: { [string]: string } = {
	Requirements = "NotQualified",
	Cooldown = "Timed",
	Owned = "Taken",
}
local RESULT_TEXT: { [string]: string } = {
	Far = "Come closer.",
	Gems = "Come back when you can pay.",
	Busy = "You already have a party waiting.",
	Invalid = "...",
}

local PICTURE = 180
local BUTTON_HEIGHT = 48
local UNTINTED = Color3.new(1, 1, 1)

local random = Random.new()

local function pick(lines: { string }?): string
	if not lines or #lines == 0 then
		return "..."
	end
	return lines[random:NextInteger(1, #lines)]
end

local function hasCompass(player: Player): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	return (backpack ~= nil and backpack:FindFirstChild(CompassConfig.ToolName) ~= nil)
		or (character ~= nil and character:FindFirstChild(CompassConfig.ToolName) ~= nil)
end

return {
	Merchants = { LegendaryConfig.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local DataController = Knit.GetController("DataController")
		local LegendaryService = Knit.GetService("LegendaryService")
		local localPlayer = Players.LocalPlayer

		local current: Fusion.Value<string?> = scope:Value(nil :: string?)
		local dialogue = scope:Value("")
		local busy = scope:Value(false)

		local function get(path: string): any
			return DataController:Get(path)
		end

		local function chooseLine(questName: string): string
			local quest = LegendaryConfig.Quests[questName]
			local lines = quest.Dialogue
			if LegendaryConfig.GetCooldownLeft(questName, get, os.time()) > 0 and lines.Timed then
				return pick(lines.Timed)
			end
			if not LegendaryConfig.MeetsRequirements(questName, get) then
				return pick(lines.NotQualified)
			end
			if lines.Taken and hasCompass(localPlayer) then
				return pick(lines.Taken)
			end
			if lines.FirstRaid and get(quest.CooldownPath) == 0 then
				return pick(lines.FirstRaid)
			end
			return pick(lines.Qualified)
		end

		local function accept()
			local questName = Fusion.peek(current)
			if not questName or Fusion.peek(busy) then
				return
			end
			busy:set(true)
			LegendaryService:Accept(questName)
				:andThen(function(result: string)
					if result == "Ok" then
						context.Close()
						return
					end
					local quest = LegendaryConfig.Quests[questName]
					local set = RESULT_LINES[result]
					if set then
						dialogue:set(pick(quest.Dialogue[set] or quest.Dialogue.NotQualified))
					else
						dialogue:set(RESULT_TEXT[result] or "...")
					end
				end)
				:catch(warn)
				:finally(function()
					busy:set(false)
				end)
		end

		local selected = scope:Computed(function(use): LegendaryConfig.Quest?
			return LegendaryConfig.Quests[use(current) or ""]
		end)
		local paid = scope:Computed(function(use): boolean
			local quest = use(selected)
			return quest ~= nil and quest.GemCost ~= nil
		end)

		local cards: { any } = {}
		for index, entry in BOARD do
			if LegendaryConfig.Quests[entry.Quest] then
				table.insert(
					cards,
					UI.Card(scope, {
						Name = entry.Quest,
						Title = entry.Title,
						Caption = entry.Party,
						Image = entry.Image,
						LayoutOrder = index,
						Size = UDim2.new(1 / #BOARD, -Theme.Space.M, 1, 0),
						OnClick = function()
							dialogue:set(chooseLine(entry.Quest))
							current:set(entry.Quest)
						end,
					})
				)
			end
		end

		MerchantDialogue.closeOnMove(scope, context.Close)

		local detailLeft = PICTURE + Theme.Space.L

		return UI.Screen(scope, {
			Name = "LegendaryQuests",
			DisplayOrder = 10,
			Children = {
				UI.Window(scope, {
					Title = "The Legendary Hero",
					Subtitle = scope:Computed(function(use): string
						local quest = use(selected)
						return if quest then quest.Title else "Quests"
					end),
					Size = UDim2.fromOffset(820, 440),
					Children = {
						UI.Stack(scope, {
							Name = "Quests",
							Direction = "Horizontal",
							Gap = Theme.Space.M,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Size = UDim2.fromScale(1, 1),
							Visible = scope:Computed(function(use): boolean
								return use(current) == nil
							end),
							Children = cards,
						}),

						scope:New("Frame")({
							Name = "SpecificTask",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Visible = scope:Computed(function(use): boolean
								return use(current) ~= nil
							end),
							[Fusion.Children] = {
								UI.Image(scope, {
									Name = "Picture",
									Image = scope:Computed(function(use): string
										local quest = use(selected)
										return if quest then quest.Image else ""
									end),
									Size = UDim2.fromOffset(PICTURE, PICTURE),
									Background = Theme.Colors.Sunken,
									Radius = Theme.Radius.Medium,
								}),
								UI.Panel(scope, {
									Name = "Bubble",
									Position = UDim2.fromOffset(detailLeft, 0),
									Size = UDim2.new(1, -detailLeft, 1, -(BUTTON_HEIGHT + Theme.Space.M)),
									Color = Theme.Colors.Sunken,
									Padding = Theme.Space.M,
									Gradient = false,
									Children = {
										UI.Label(scope, {
											Name = "Dialogue",
											Text = dialogue,
											Scaled = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											TextYAlignment = Enum.TextYAlignment.Top,
											Size = UDim2.fromScale(1, 1),
										}),
									},
								}),
								UI.Button(scope, {
									Name = "Return",
									Text = "Return",
									Variant = "Secondary",
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.fromOffset(PICTURE, BUTTON_HEIGHT),
									OnClick = function()
										current:set(nil)
									end,
								}),
								-- Paid quests show their gem price, next to the gem icon.
								UI.Button(scope, {
									Name = "Accept",
									Text = "Accept",
									Disabled = busy,
									AnchorPoint = Vector2.new(1, 1),
									Position = UDim2.fromScale(1, 1),
									Size = UDim2.new(1, -detailLeft, 0, BUTTON_HEIGHT),
									Visible = scope:Computed(function(use): boolean
										return not use(paid)
									end),
									OnClick = accept,
								}),
								UI.Button(scope, {
									Name = "AcceptPaid",
									Text = scope:Computed(function(use): string
										local quest = use(selected)
										return if quest and quest.GemCost then `Accept for {quest.GemCost}` else "Accept"
									end),
									Icon = GEM_ICON,
									IconColor = UNTINTED,
									Disabled = busy,
									AnchorPoint = Vector2.new(1, 1),
									Position = UDim2.fromScale(1, 1),
									Size = UDim2.new(1, -detailLeft, 0, BUTTON_HEIGHT),
									Visible = paid,
									OnClick = accept,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
