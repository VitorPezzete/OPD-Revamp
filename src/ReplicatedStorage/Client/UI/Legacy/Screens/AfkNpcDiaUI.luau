--!strict
--[[
	The AFK NPC dialog: lists what the player earned in the AFK world (data.AFK_World)
	and claims it. The amounts shown are the replicated data; the claim request carries
	nothing, AfkRewardService pays out what is actually saved.

	The old green board: the NPC's line in the dark box on the left, the five rewards as
	a column of grey rows beside it, the claim button under them. The old GUI never filled
	its NPC name and dialogue labels ("Npc Name", "Dialogue Template Bla Bla Bla"): they
	get the title and the line of the rework's window. Its portrait had no picture (an
	empty grey square on the right), so the board is as wide as what it really shows.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

-- { name of the row, prefix, data.AFK_World field }, in the order of the old list.
local REWARDS: { { string } } = {
	{ "BeriReward", "Beri: ", "Beri" },
	{ "GemsReward", "Gems: ", "Gems" },
	{ "CompassReward", "Compasses: ", "Compass" },
	{ "SilverReward", "Silver Compasses: ", "SilverCompass" },
	{ "GoldenReward", "Golden Compasses: ", "GoldenCompass" },
}

local TITLE = "AFK Rewards"
local LINE = "This is what you earned in the AFK world. Claim it whenever you like."

local BOARD_COLOR = Color3.fromRGB(0, 170, 0)
-- The default grey of the old reward labels.
local ROW_COLOR = Color3.fromRGB(163, 162, 165)

-- Design pixels. The old board was 0.6 of the screen's height tall.
local WINDOW_SIZE = Vector2.new(900, 620)
local TITLE_HEIGHT = 56
local DIALOGUE_WIDTH = 300
local ROW_HEIGHT = 60
local BUTTON_SIZE = Vector2.new(280, 52)

return {
	Merchants = { "AFK_NPC" },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local pending = Bind.data(scope, "AFK_World", {})
		local claiming = scope:Value(false)
		local closed = false
		table.insert(scope, function()
			closed = true
		end)

		local function claim()
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
		end

		local rows: { any } = {}
		for order, reward in REWARDS do
			table.insert(
				rows,
				Kit.Well(scope, {
					Name = reward[1],
					LayoutOrder = order,
					Color = ROW_COLOR,
					Transparency = 0.25,
					Padding = Kit.Space.S,
					Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
					Children = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
						Kit.Label(scope, {
							Text = scope:Computed(function(use): string
								local saved = use(pending)
								local amount = if type(saved) == "table" then saved[reward[3]] else nil
								return reward[2] .. Bind.formatNumber(if type(amount) == "number" then amount else 0)
							end),
							TextSize = Kit.TextSize.Heading,
							Fit = true,
							Size = UDim2.fromScale(1, 1),
						}),
					},
				})
			)
		end

		local contentTop = TITLE_HEIGHT + Kit.Space.S
		local contentHeight = -(contentTop + Kit.Space.S + ShopScreen.HINT_HEIGHT)

		local window = ShopScreen.Board(scope, {
			Color = BOARD_COLOR,
			Transparency = 0.5,
			Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
			Children = {
				Kit.Label(scope, {
					Name = "Shop",
					Text = TITLE,
					TextSize = Kit.TextSize.Title,
					Fit = true,
					Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
				}),

				Kit.Well(scope, {
					Name = "Dia",
					Transparency = 0.7,
					Padding = Kit.Space.M,
					Position = UDim2.fromOffset(0, contentTop),
					Size = UDim2.new(0, DIALOGUE_WIDTH, 1, contentHeight),
					Children = {
						Kit.Label(scope, {
							Text = LINE,
							TextSize = Kit.TextSize.Heading,
							Fit = true,
							Size = UDim2.fromScale(1, 1),
						}),
					},
				}),

				scope:New("Frame")({
					Name = "Rewards",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, contentTop),
					Size = UDim2.new(1, -(DIALOGUE_WIDTH + Kit.Space.XL), 1, contentHeight),
					[Fusion.Children] = {
						Kit.Stack(scope, {
							Name = "List",
							Gap = Kit.Space.S,
							Size = UDim2.new(1, 0, 1, -(BUTTON_SIZE.Y + Kit.Space.L)),
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Children = rows,
						}),
						Kit.Button(scope, {
							Name = "Sell",
							Variant = "Grey",
							Text = scope:Computed(function(use): string
								return if use(claiming) then "Claiming..." else "Claim Rewards"
							end),
							Disabled = claiming,
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.fromScale(0.5, 1),
							Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
							OnClick = claim,
						}),
					},
				}),

				ShopScreen.Hint(scope, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
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
