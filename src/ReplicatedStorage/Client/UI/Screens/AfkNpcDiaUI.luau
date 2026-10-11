--!strict
--[[
	The AFK NPC dialog: lists what the player earned in the AFK world (data.AFK_World)
	and claims it. The amounts shown are the replicated data; the claim request carries
	nothing, AfkRewardService pays out what is actually saved.

	The legacy GUI never filled its NPC name and dialogue labels ("Npc Name", "Dialogue
	Template Bla Bla Bla"); the window has a title and a line of its own instead.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MerchantSpeech = require(ReplicatedStorage.Client.UI.Components.MerchantSpeech)
local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

type Scope = Theme.Scope

-- { row name, label, data.AFK_World field, colour of the amount }
local REWARDS: { { any } } = {
	{ "BeriReward", "Beri", "Beri", Theme.Colors.Beri },
	{ "GemsReward", "Gems", "Gems", Theme.Colors.Gems },
	{ "CompassReward", "Compasses", "Compass", Theme.Colors.Text },
	{ "SilverReward", "Silver Compasses", "SilverCompass", Theme.Colors.Text },
	{ "GoldenReward", "Golden Compasses", "GoldenCompass", Theme.Colors.Warning },
}

local SPEECH_HEIGHT = 72
local ROW_HEIGHT = 46
local ROW_GAP = Theme.Space.XS
local BUTTON_HEIGHT = 52
local HINT_HEIGHT = 22
local GAP = Theme.Space.M

return {
	Merchants = { "AFK_NPC" },

	Mount = function(scope: Scope, _gui: any, context: any)
		local pending = Bind.data(scope :: any, "AFK_World", {})
		local claiming = scope:Value(false)
		local closed = false
		table.insert(scope, function()
			closed = true
		end)

		local rows: { any } = {}
		for index, reward in REWARDS do
			rows[index] = UI.Panel(scope, {
				Name = reward[1],
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
				Color = Theme.Colors.Raised,
				Padding = Theme.Space.M,
				Children = {
					UI.Label(scope, {
						Name = "Title",
						Text = reward[2],
						Variant = "Body",
						TextXAlignment = Enum.TextXAlignment.Left,
						Size = UDim2.fromScale(0.6, 1),
					}),
					UI.Label(scope, {
						Name = "Amount",
						Text = scope:Computed(function(use): string
							local saved = use(pending)
							local amount = if type(saved) == "table" then saved[reward[3]] else nil
							return Bind.formatNumber(if type(amount) == "number" then amount else 0)
						end),
						Variant = "BodyBold",
						Color = reward[4],
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.4, 1),
					}),
				},
			})
		end

		ShopWindow.closeOnMove(scope, context)

		local listTop = SPEECH_HEIGHT + GAP
		local listHeight = #REWARDS * ROW_HEIGHT + (#REWARDS - 1) * ROW_GAP
		local buttonTop = listTop + listHeight + GAP
		local bodyHeight = buttonTop + BUTTON_HEIGHT + Theme.Space.S + HINT_HEIGHT

		return UI.Screen(scope, {
			Name = "AfkNpcDiaUI",
			Children = UI.Window(scope, {
				Title = "AFK Rewards",
				Size = UDim2.fromOffset(520, 52 + Theme.Space.L * 2 + bodyHeight),
				Children = {
					MerchantSpeech(scope, {
						Text = "This is what you earned in the AFK world. Claim it whenever you like.",
						Height = SPEECH_HEIGHT,
					}),
					UI.Stack(scope, {
						Name = "Rewards",
						Position = UDim2.fromOffset(0, listTop),
						Size = UDim2.new(1, 0, 0, listHeight),
						Gap = ROW_GAP,
						Children = rows,
					}),
					UI.Button(scope, {
						Name = "Sell",
						Text = scope:Computed(function(use): string
							return if use(claiming) then "Claiming..." else "Claim Rewards"
						end),
						Variant = "Success",
						Disabled = claiming,
						Position = UDim2.fromOffset(0, buttonTop),
						Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
						OnClick = function()
							if Fusion.peek(claiming) then
								return
							end
							claiming:set(true)
							Knit.GetService("AfkRewardService")
								:Claim()
								:andThen(function()
									context.Close()
								end)
								:catch(warn)
								:finally(function()
									if not closed then
										claiming:set(false)
									end
								end)
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
