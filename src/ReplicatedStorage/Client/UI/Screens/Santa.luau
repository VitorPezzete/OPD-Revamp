--!strict
--[[
	Santa's dialog (Christmas event). Shows the stage of the event quest saved in
	data.Events: XMasLevel 0 bring a Candy Fruit, 1 deliver candies to five NPCs
	(XMasTask = "0".."4"), 2 gift candies to ten different players (XMasTask = a comma
	separated list of who was gifted), 3 done.

	DISABLED: the event itself is not ported. The screen opens only if a "Santa" merchant
	exists, displays the saved progress, and its button just closes the dialog.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MerchantSpeech = require(ReplicatedStorage.Client.UI.Components.MerchantSpeech)
local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

type Scope = Theme.Scope
type Stage = { Dia: string, Task: string }

local PORTRAIT = "rbxassetid://93582926537892"
local GIFTS_GOAL = 10

local SPEECH_HEIGHT = 150
local TASK_HEIGHT = 68
local PROGRESS_HEIGHT = 56
local BUTTON_HEIGHT = 50
local HINT_HEIGHT = 22
local GAP = Theme.Space.M

local INTRO: Stage = {
	Dia = "Ho Ho Ho! Merry Christmas! Mind helping me make this christimas special? I Lost all my candy, do you got some there?",
	Task = "Bring a Candy Fruit",
}
-- XMasLevel 1, by XMasTask.
local DELIVERIES: { [string]: Stage } = {
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
local GIFTING: Stage = {
	Dia = "Hey, i got these candies... They are good for starters, mind looking out for some and giving them it?",
	Task = "Deliver candies to different players",
}
local DONE: Stage = {
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

	Mount = function(scope: Scope, _gui: any, context: any)
		local events = Bind.data(scope :: any, "Events", {})
		local saved = scope:Computed(function(use): { [string]: any }
			local current = use(events)
			return if type(current) == "table" then current else {}
		end)
		local stage = scope:Computed(function(use): Stage
			local current = use(saved)
			local level = current.XMasLevel
			if level == 1 then
				return DELIVERIES[tostring(current.XMasTask)] or DELIVERIES["0"]
			elseif level == 2 then
				return GIFTING
			elseif level == 3 then
				return DONE
			end
			return INTRO
		end)
		local gifting = scope:Computed(function(use): boolean
			return use(saved).XMasLevel == 2
		end)
		local gifts = scope:Computed(function(use): number
			local current = use(saved)
			return if current.XMasLevel == 2 then countGifts(current.XMasTask) else 0
		end)

		ShopWindow.closeOnMove(scope, context)

		local taskTop = SPEECH_HEIGHT + GAP
		local progressTop = taskTop + TASK_HEIGHT + GAP
		local buttonTop = progressTop + PROGRESS_HEIGHT + GAP
		local bodyHeight = buttonTop + BUTTON_HEIGHT + Theme.Space.S + HINT_HEIGHT

		return UI.Screen(scope, {
			Name = "Santa",
			Children = UI.Window(scope, {
				Title = "Joy To The World!",
				Size = UDim2.fromOffset(700, 52 + Theme.Space.L * 2 + bodyHeight),
				Children = {
					MerchantSpeech(scope, {
						Portrait = PORTRAIT,
						Speaker = "Santa",
						Text = scope:Computed(function(use): string
							return use(stage).Dia
						end),
						Height = SPEECH_HEIGHT,
					}),

					UI.Panel(scope, {
						Name = "TaskPanel",
						Position = UDim2.fromOffset(0, taskTop),
						Size = UDim2.new(1, 0, 0, TASK_HEIGHT),
						Padding = Theme.Space.M,
						Children = {
							UI.Label(scope, {
								Name = "Caption",
								Text = "Task",
								Variant = "Tiny",
								TextXAlignment = Enum.TextXAlignment.Left,
								Size = UDim2.new(1, 0, 0, 16),
							}),
							UI.Label(scope, {
								Name = "Task",
								Text = scope:Computed(function(use): string
									return use(stage).Task
								end),
								Variant = "BodyBold",
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, 24),
							}),
						},
					}),

					scope:New("Frame")({
						Name = "Quantity",
						Position = UDim2.fromOffset(0, progressTop),
						Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT),
						BackgroundTransparency = 1,
						Visible = gifting,
						[Fusion.Children] = {
							UI.Label(scope, {
								Name = "Caption",
								Text = "Players gifted",
								Variant = "Small",
								TextXAlignment = Enum.TextXAlignment.Left,
								Size = UDim2.new(1, 0, 0, 22),
							}),
							UI.ProgressBar(scope, {
								Name = "Progress",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, PROGRESS_HEIGHT - 28),
								Color = Theme.Colors.Success,
								Value = scope:Computed(function(use): number
									return use(gifts) / GIFTS_GOAL
								end),
								Text = scope:Computed(function(use): string
									return `{use(gifts)} / {GIFTS_GOAL}`
								end),
							}),
						},
					}),

					-- Event disabled: nothing to request from the server.
					UI.Button(scope, {
						Name = "Complete",
						Text = "Complete Task",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, buttonTop),
						Size = UDim2.fromOffset(260, BUTTON_HEIGHT),
						OnClick = function()
							context.Close()
						end,
					}),
					UI.Label(scope, {
						Name = "Hint",
						Text = ShopWindow.HINT,
						Variant = "Tiny",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
					}),
				},
			}),
		})
	end,
}
