--!strict
--[[
	The Legendary Hero's quest board (legacy LegendaryQuests / QuestsHandler): the old
	yellow dialogue window, "The Legendary Hero" across the top, the hero standing at the
	right, and at the left a faded parchment holding the list of quests (picture, name,
	party size). Picking one turns the parchment into that quest's page - its picture,
	its title and what the hero says - with Accept (blue) and Return (grey) under it.

	Picking a quest shows the hero's line for the player's situation: on cooldown, not
	qualified, already holding the compass, first raid, or qualified. The line is chosen
	from the replicated data with the predicates of LegendaryConfig, the same ones the
	server enforces when Accept is pressed; the server's answer replaces the line when it
	disagrees (and says why in a notification: what is missing, or the minutes left).
	Walking away closes the board, as it always did (RaidController closes it too when a
	lobby opens).

	The legacy script kept its own copy of the requirement tables and let Accept through
	whatever the hero had just said.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local CompassConfig = require(ReplicatedStorage.Shared.Configs.CompassConfig)
local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local DialogueBox = require(ReplicatedStorage.Client.UI.Legacy.Components.DialogueBox)
local GemPrice = require(ReplicatedStorage.Client.UI.Legacy.Components.GemPrice)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)

type Scope = Fusion.Scope<typeof(Fusion)>

-- The board as the old one listed it: order, short name, party size and picture of each
-- quest of LegendaryConfig.
local BOARD: { { Quest: string, Title: string, Party: string, Image: string } } = {
	{ Quest = "FireBoss", Title = "Fire Boss", Party = "1 Player", Image = "rbxassetid://134273497267016" },
	{ Quest = "MarineRaid", Title = "Marine Raid", Party = "1-4 Players", Image = "rbxassetid://77909306485141" },
	{ Quest = "Endless", Title = "Endless", Party = "1-4 Players", Image = "rbxassetid://113491974530196" },
}

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

local DISPLAY_ORDER = 10

local OUTER_COLOR = Color3.fromRGB(221, 217, 107)
local INNER_COLOR = Color3.fromRGB(163, 162, 165)
local INNER_TRANSPARENCY = 0.4
local HERO = "rbxassetid://138467108908389"
local PICTURE_COLOR = Color3.fromRGB(171, 171, 171)
local PARCHMENT_TRANSPARENCY = 0.6

local BOARD_WIDTH = 740
local ROW_HEIGHT = 120
-- The pictures are 4:3.
local ROW_PICTURE = Vector2.new(160, ROW_HEIGHT)
local PAGE_PICTURE = Vector2.new(240, 180)
local PAGE_TITLE_HEIGHT = 56
local BUTTON_SIZE = UDim2.fromOffset(260, 60)
local BUTTON_GEM = 40

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

		-- A quest picture on the grey the old ones stood on.
		local function picture(image: Fusion.UsedAs<string>, size: Vector2): Instance
			return Kit.Well(scope, {
				Name = "Picture",
				Color = PICTURE_COLOR,
				Transparency = 0,
				Size = UDim2.fromOffset(size.X, size.Y),
				Children = {
					Kit.Image(scope, {
						Image = image,
						ScaleType = Enum.ScaleType.Stretch,
						Size = UDim2.fromScale(1, 1),
					}),
				},
			})
		end

		local rows: { any } = {}
		for index, entry in BOARD do
			if not LegendaryConfig.Quests[entry.Quest] then
				continue
			end
			local textLeft = ROW_PICTURE.X + Kit.Space.L
			table.insert(
				rows,
				-- The whole row is the button.
				Kit.Button(scope, {
					Name = entry.Quest,
					Variant = "Ghost",
					Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
					LayoutOrder = index,
					OnClick = function()
						dialogue:set(chooseLine(entry.Quest))
						current:set(entry.Quest)
					end,
					Children = {
						Kit.Well(scope, {
							Name = "Back",
							Transparency = 0.8,
							Size = UDim2.fromScale(1, 1),
							ZIndex = 0,
						}),
						picture(entry.Image, ROW_PICTURE),
						Kit.Label(scope, {
							Name = "Title",
							Text = entry.Title,
							TextSize = Kit.TextSize.Title,
							Fit = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							Position = UDim2.fromOffset(textLeft, Kit.Space.M),
							Size = UDim2.new(1, -(textLeft + Kit.Space.M), 0.5, -Kit.Space.M),
						}),
						Kit.Label(scope, {
							Name = "Party",
							Text = entry.Party,
							Color = Kit.Colors.TextDim,
							TextXAlignment = Enum.TextXAlignment.Left,
							Position = UDim2.new(0, textLeft, 0.5, 0),
							Size = UDim2.new(1, -(textLeft + Kit.Space.M), 0.5, -Kit.Space.M),
						}),
					},
				})
			)
		end

		-- Closes when the player walks away, dies or has no character.
		MerchantDialogue.closeOnMove(scope, context.Close)

		local buttonRow = BUTTON_SIZE.Y.Offset + Kit.Space.L
		local pageLeft = PAGE_PICTURE.X + Kit.Space.L

		return Kit.Screen(scope, {
			Name = "LegendaryQuests",
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				-- A window for the gamepad; like the rework's it has no close button.
				DialogueBox.new(scope, {
					Title = "The Legendary Hero",
					Color = OUTER_COLOR,
					InnerColor = INNER_COLOR,
					InnerTransparency = INNER_TRANSPARENCY,
					Children = {
						Kit.Image(scope, {
							Name = "Hero",
							Image = HERO,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(1, -(BOARD_WIDTH + Kit.Space.XL), 1, 0),
						}),

						Kit.Panel(scope, {
							Name = "QuestsBackground",
							ImageTransparency = PARCHMENT_TRANSPARENCY,
							Size = UDim2.new(0, BOARD_WIDTH, 1, 0),
							Padding = Kit.Space.M,
							Visible = scope:Computed(function(use): boolean
								return use(current) == nil
							end),
							Children = {
								Kit.Scroll(scope, {
									Name = "Quests",
									Background = false,
									Padding = 0,
									Children = rows,
								}),
							},
						}),

						scope:New("Frame")({
							Name = "SpecificTask",
							BackgroundTransparency = 1,
							Size = UDim2.new(0, BOARD_WIDTH, 1, 0),
							Visible = scope:Computed(function(use): boolean
								return use(current) ~= nil
							end),
							[Fusion.Children] = {
								Kit.Panel(scope, {
									Name = "QuestsBackground",
									ImageTransparency = PARCHMENT_TRANSPARENCY,
									Size = UDim2.new(1, 0, 1, -buttonRow),
									Padding = Kit.Space.L,
									Children = {
										picture(
											scope:Computed(function(use): string
												local quest = use(selected)
												return if quest then quest.Image else ""
											end),
											PAGE_PICTURE
										),
										Kit.Label(scope, {
											Name = "Title",
											Text = scope:Computed(function(use): string
												local quest = use(selected)
												return if quest then quest.Title else ""
											end),
											TextSize = Kit.TextSize.Title,
											Fit = true,
											Position = UDim2.fromOffset(pageLeft, 0),
											Size = UDim2.new(1, -pageLeft, 0, PAGE_TITLE_HEIGHT),
										}),
										Kit.Label(scope, {
											Name = "Dialogue",
											Text = dialogue,
											TextSize = Kit.TextSize.Heading,
											-- A long line shrinks to the page instead of running out of it.
											Fit = true,
											Position = UDim2.fromOffset(pageLeft, PAGE_TITLE_HEIGHT + Kit.Space.M),
											Size = UDim2.new(1, -pageLeft, 1, -(PAGE_TITLE_HEIGHT + Kit.Space.M)),
										}),
									},
								}),
								Kit.Stack(scope, {
									Name = "Buttons",
									Direction = "Horizontal",
									Gap = Kit.Space.XL,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(1, 0, 0, BUTTON_SIZE.Y.Offset),
									Children = {
										-- Paid quests show their gem price on the button, next to the gem.
										Kit.Button(scope, {
											Name = "Accept",
											Variant = "Blue",
											TextSize = Kit.TextSize.Heading,
											Size = BUTTON_SIZE,
											LayoutOrder = 1,
											Text = scope:Computed(function(use): string
												local quest = use(selected)
												return if quest and quest.GemCost then tostring(quest.GemCost) else "Accept"
											end),
											-- Greyed out while a request is on its way.
											Disabled = busy,
											OnClick = accept,
											Children = {
												Kit.Image(scope, {
													Name = "Gem",
													Image = GemPrice.Icon,
													AnchorPoint = Vector2.new(1, 0.5),
													Position = UDim2.new(1, -Kit.Space.M, 0.5, 0),
													Size = UDim2.fromOffset(BUTTON_GEM, BUTTON_GEM),
													ZIndex = 3,
													Visible = paid,
												}),
											},
										}),
										Kit.Button(scope, {
											Name = "Return",
											Text = "Return",
											Variant = "Grey",
											TextSize = Kit.TextSize.Heading,
											Size = BUTTON_SIZE,
											LayoutOrder = 2,
											OnClick = function()
												current:set(nil)
											end,
										}),
									},
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
