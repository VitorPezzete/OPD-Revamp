--!strict
--[[
	Santa's dialog (Christmas event). Shows the stage of the event quest saved in
	data.Events: XMasLevel 0 bring a Candy Fruit, 1 deliver candies to five NPCs
	(XMasTask = "0".."4"), 2 gift candies to ten different players (XMasTask = a comma
	separated list of who was gifted), 3 done.

	DISABLED: the event itself is not ported. In the legacy place the Santa NPC only
	existed in December (the server ignored requests before day 335 of the year and the
	model sat in ServerStorage.Events.XMas the rest of the time), and the quest steps live
	in the Candy tool scripts. The screen therefore opens only if a "Santa" merchant
	exists, displays the saved progress, and its button just closes the dialog.

	The old pink board with its red sheet, in three columns: what Santa says on the left,
	the task and its button in the middle, his portrait over the "players gifted" gauge on
	the right.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local GIFTS_GOAL = 10

local OUTER_COLOR = Color3.fromRGB(221, 199, 216)
local INNER_COLOR = Color3.fromRGB(221, 37, 62)
local TASK_COLOR = Color3.fromRGB(249, 76, 255)
local GIFTS_COLOR = Color3.fromRGB(124, 37, 255)
local GAUGE_BACK = Color3.fromRGB(48, 48, 48)
local NPC_IMAGE = "rbxassetid://93582926537892"

-- Design pixels. The old board was 1.2 x 0.6 of the screen's height.
local WINDOW_SIZE = Vector2.new(1220, 620)
local FRAME_MARGIN = 30
local TITLE_HEIGHT = 56
local SIDE_WIDTH = 300
local PORTRAIT_SIZE = 250
local TASK_HEIGHT = 150
local BUTTON_SIZE = Vector2.new(260, 52)
local GAUGE_LABEL_HEIGHT = 26
local GAUGE_HEIGHT = 22

local INTRO = {
	Dia = "Ho Ho Ho! Merry Christmas! Mind helping me make this christimas special? I Lost all my candy, do you got some there?",
	Task = "Bring a Candy Fruit",
}
-- XMasLevel 1, by XMasTask.
local DELIVERIES: { [string]: { Dia: string, Task: string } } = {
	["0"] = {
		Dia = "Thank you! Now I need to deliver this candy to my friend Sam",
		Task = "Deliver candies to Sam",
	},
	["1"] = {
		Dia = "Thank you! Can you deliver this one to merlin?",
		Task = "Deliver candies to Merlin",
	},
	["2"] = {
		Dia = "Thank you! Oh yeah, we can't forget the Beverages dealer",
		Task = "Deliver candies to the Beverages dealer",
	},
	["3"] = {
		Dia = "Thank you! Have you seen my old friend lucy anywhere? I needed to give her it, but i can't find her...",
		Task = "Deliver candies to Lucy",
	},
	["4"] = {
		Dia = "Thank you! I saw there's a new guy around here, mind giving it to him?",
		Task = "Deliver candies to Suspicious Guy",
	},
}
local GIFTING = {
	Dia = "Hey, i got these candies... They are good for starters, mind looking out for some and giving them it?",
	Task = "Deliver candies to different players",
}
local DONE = {
	Dia = "Merry Christmas! I'm done for now, come back next year! Here's a little gift",
	Task = "Complete",
}

-- The gifted list is stored with a trailing comma: "a,b," is two players.
local function countGifts(gifted: any): number
	if type(gifted) ~= "string" then
		return 0
	end
	return math.clamp(#string.split(gifted, ",") - 1, 0, GIFTS_GOAL)
end

return {
	Merchants = { "Santa" },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local events = Bind.data(scope, "Events", {})
		local progress = scope:Computed(function(use): { [string]: any }
			local current = use(events)
			return if type(current) == "table" then current else {}
		end)
		local stage = scope:Computed(function(use)
			local saved = use(progress)
			local level = saved.XMasLevel
			if level == 1 then
				return DELIVERIES[tostring(saved.XMasTask)] or DELIVERIES["0"]
			elseif level == 2 then
				return GIFTING
			elseif level == 3 then
				return DONE
			end
			return INTRO
		end)
		local gifts = scope:Computed(function(use): number
			local saved = use(progress)
			return if saved.XMasLevel == 2 then countGifts(saved.XMasTask) else 0
		end)
		local gifting = scope:Computed(function(use): boolean
			return use(progress).XMasLevel == 2
		end)

		local contentTop = TITLE_HEIGHT + Kit.Space.S
		local contentHeight = -(contentTop + Kit.Space.S + ShopScreen.HINT_HEIGHT)
		local middleWidth = -2 * (SIDE_WIDTH + Kit.Space.XL)

		local window = ShopScreen.Board(scope, {
			Color = OUTER_COLOR,
			Transparency = 0.5,
			Padding = FRAME_MARGIN,
			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
			Children = {
				ShopScreen.Board(scope, {
					Name = "Frame",
					Color = INNER_COLOR,
					Transparency = 0.5,
					Padding = Kit.Space.L,
					Size = UDim2.fromScale(1, 1),
					Children = {
						Kit.Label(scope, {
							Name = "shop",
							Text = "Joy To The World!",
							TextSize = Kit.TextSize.Title,
							Fit = true,
							Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						}),

						Kit.Well(scope, {
							Name = "Dia",
							Transparency = 0.7,
							Padding = Kit.Space.M,
							Position = UDim2.fromOffset(0, contentTop),
							Size = UDim2.new(0, SIDE_WIDTH, 1, contentHeight),
							Children = {
								Kit.Label(scope, {
									Text = scope:Computed(function(use): string
										return use(stage).Dia
									end),
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Quest",
							Gap = Kit.Space.XL,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, contentTop),
							Size = UDim2.new(1, middleWidth, 1, contentHeight),
							Children = {
								Kit.Well(scope, {
									Name = "Task",
									LayoutOrder = 1,
									Color = TASK_COLOR,
									Transparency = 0.7,
									Padding = Kit.Space.M,
									Size = UDim2.new(1, 0, 0, TASK_HEIGHT),
									Children = {
										Kit.Label(scope, {
											Text = scope:Computed(function(use): string
												return use(stage).Task
											end),
											TextSize = Kit.TextSize.Title,
											Fit = true,
											Size = UDim2.fromScale(1, 1),
										}),
									},
								}),
								-- Event disabled: nothing to request from the server.
								Kit.Button(scope, {
									Name = "Complete",
									LayoutOrder = 2,
									Variant = "Grey",
									Text = "Complete Task",
									Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
									OnClick = function()
										context.Close()
									end,
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Santa",
							Gap = Kit.Space.S,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, contentTop),
							Size = UDim2.new(0, SIDE_WIDTH, 1, contentHeight),
							Children = {
								Kit.Image(scope, {
									Name = "NPC",
									LayoutOrder = 1,
									Image = NPC_IMAGE,
									Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE),
								}),
								-- The gauge keeps its room while hidden, so the portrait does not jump.
								scope:New("Frame")({
									Name = "Quantity",
									LayoutOrder = 2,
									BackgroundTransparency = 1,
									Size = UDim2.new(1, 0, 0, 2 * GAUGE_LABEL_HEIGHT + GAUGE_HEIGHT + 2 * Kit.Space.XS),
									[Fusion.Children] = {
										Kit.Stack(scope, {
											Gap = Kit.Space.XS,
											Size = UDim2.fromScale(1, 1),
											Visible = gifting,
											Children = {
												Kit.Label(scope, {
													LayoutOrder = 1,
													Text = "Players gifted",
													Color = GIFTS_COLOR,
													TextSize = Kit.TextSize.Small,
													Fit = true,
													Size = UDim2.new(1, 0, 0, GAUGE_LABEL_HEIGHT),
												}),
												Kit.Bar(scope, {
													LayoutOrder = 2,
													Size = UDim2.new(1, 0, 0, GAUGE_HEIGHT),
													Color = GIFTS_COLOR,
													BackColor = GAUGE_BACK,
													Value = scope:Computed(function(use): number
														return use(gifts) / GIFTS_GOAL
													end),
												}),
												Kit.Label(scope, {
													Name = "Progress",
													LayoutOrder = 3,
													Text = scope:Computed(function(use): string
														return `{use(gifts)} / {GIFTS_GOAL}`
													end),
													Color = GIFTS_COLOR,
													TextSize = Kit.TextSize.Small,
													Fit = true,
													Size = UDim2.new(1, 0, 0, GAUGE_LABEL_HEIGHT),
												}),
											},
										}),
									},
								}),
							},
						}),

						ShopScreen.Hint(scope, {
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.fromScale(0, 1),
						}),
					},
				}),
			},
		})

		ShopScreen.closeOnMove(scope, context)

		return Kit.Screen(scope, {
			Name = context.Name,
			Children = { window },
		})
	end,
}
