--!strict
--[[
	"What A Great Friend" (FriendMerchant): strange compasses for aura tokens.

	Aura tokens are bought, and only the owner of a private server can trade them (the
	server enforces it). Every so many claimed compasses add a "???" strange compass;
	the bar shows the progress. With no tokens the buttons open the purchase prompt.
	Meanwhile the friend tells his story, one line after the other, in a loop.

	The old purple board, in three columns: what the friend says on the left, the tokens
	(count, compass, claim buttons, the odds) in the middle, his portrait over the golden
	compass gauge on the right.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>

local TOKENS = FruitEconomyConfig.Tokens
local EMPTY_TRANSPARENCY = 0.7

local OUTER_COLOR = Color3.fromRGB(225, 2, 255)
local INNER_COLOR = Color3.fromRGB(216, 83, 221)
local TOKEN_COLOR = Color3.fromRGB(138, 138, 255)
local GOLD_COLOR = Color3.fromRGB(255, 197, 61)
local GAUGE_BACK = Color3.fromRGB(48, 48, 48)
local NPC_IMAGE = "rbxassetid://13677309386"
local COMPASS_IMAGE = "rbxassetid://9289714801"
local WARNING = "Strange Compasses have a 1 in 3 chance of resulting in an Aura Box of any rarity. "
	.. "Golden Aura Compasses always result in an Aura Box of Rare or Ultra Rare rarity."

-- Design pixels. The old board was 1.2 x 0.6 of the screen's height.
local WINDOW_SIZE = Vector2.new(1220, 620)
local FRAME_MARGIN = 30
local TITLE_HEIGHT = 56
local SIDE_WIDTH = 300
local PORTRAIT_SIZE = 250
local COMPASS_SIZE = 150
local TOP_LABEL_HEIGHT = 36
local CLAIM_WIDTH = 150
local CLAIM_HEIGHT = 52
local LINE_SECONDS = 6
local LONG_LINE_SECONDS = 12

-- { seconds the line stays up, text }.
local STORY: { { any } } = {
	{ LONG_LINE_SECONDS, "Hey buddy! Good to see ya! How have you been? Tell me all about it. Oh- wait. Before we get into it. I found some wierd.. things." },
	{ LINE_SECONDS, "I guess I could part with them. For a finder's fee. Ok, anyways. My boat crashed and broke apart on some rocks. I was drifting in the sea when.." },
	{ LINE_SECONDS, "These crabs found me on one of the shores that I washed up on. They welcomed me into their crab tribe! I got to meet all their family and friends!" },
	{ LINE_SECONDS, "They were all so amazing! I got to meet Abby, Brock, Charlie, Deanie, Ezra, Frudda, Gubby, Henry, Iggy, Jeffry, Kenny, Lenny, Mona, Noona, Oprah, ..." },
	{ LINE_SECONDS, "Penn, Quetzl, Rosa, Stompy, Tessa, Umi, Vicky, Walter, Xander, Yammy, and Ziggy! We got to eat little bits of sand while we sat on the beach together." },
	{ LINE_SECONDS, "We sang songs. Well, I sang songs and they seemed to enjoy my singing. So we stayed up all night and had a party! Then I drank too much sea water.." },
	{ LINE_SECONDS, "..and passed out before we could finish our singing party. So I tried building a new boat with some scraps that I found lying around on the island." },
	{ LINE_SECONDS, "I didn't make a very good boat at first, but hey! I was still learning! Well, I'm still learning even today. But, that won't stop me!" },
	{ LINE_SECONDS, "I'm gonna be a great ship builder, too! So I made my little raft and started setting sail. It didn't take long for my raft to get pulled apart by the waves." },
	{ LINE_SECONDS, "I was barely holding on to some of the drift wood when it washed me onto a new beach. Not the same crab beach like last time. Oh, no." },
	{ LINE_SECONDS, "This was a new beach, mind you. So I had a look around and you won't believe my disappointment when there were no crabs. I made such wonderful friends." },
	{ LINE_SECONDS, "I'll never forget all 25 of them! But, I could waste anymore time worrying about my crab friends." },
	{ LINE_SECONDS, "I had to escape this new beach or I'd be back to drinking sea water again! Ha ha! And last time didn't go so well." },
	{ LINE_SECONDS, "So, you see, I had to find some good wood for a new raft! But, wouldn't you know it.. There weren't any trees on this new island!" },
	{ LINE_SECONDS, "How can an island not have any trees? that's ridiculous! Well, the beach sand wasn't exactly sand. It was more like rocks. With.. moss?" },
	{ LINE_SECONDS, "I can't be sure. So I looked around for something to build a boat with, but there wasn't any useful building material." },
	{ LINE_SECONDS, "I wouldn't say it was a complete loss, though. Since the island was fully inhabited!" },
	{ LINE_SECONDS, "I was so amazed to find someone other than crabs that I nearly lept a hundred feet in the air with glee!" },
	{ LINE_SECONDS, "Finally, I could find some normal people to talk to. You wouldn't believe how much a crab can talk your ear off." },
	{ LINE_SECONDS, "I mean, geez. Have you ever talked with a crab before? Pff. But, these guys didn't seem to like talking.." },
	{ LINE_SECONDS, "Actually, they seemed to rather enjoy swords. And guns. And they didn't like me standing on their pretty rocks, for some reason?" },
	{ LINE_SECONDS, "Well, I thought I'd introduce myself to some friendly inhabitants. And yet, all I got were these angry rock people!" },
	{ LINE_SECONDS, "They weren't actually made of rocks, mind you. They just lived on rocks. So I call them rock people." },
	{ LINE_SECONDS, "I don't know if the rock people actually liked living on rocks. It seemed like a pretty harsh place to live. What if you needed to build a boat?" },
	{ LINE_SECONDS, "I couldn't build a boat to leave, because there were no trees! Just rocks! So how would these guys go from island to island?" },
	{ LINE_SECONDS, "I tried asking, but I found myself swimming away from that island really fast. They didn't like me being there, and they said so!" },
	{ LINE_SECONDS, "With their swords and guns that is. I wonder if I'll ever see my rock friends ever again?" },
	{ LINE_SECONDS, "But, with the rock island on the far horizon, I had to find myself ashore somewhere new. I swam until the waves turned purple." },
	{ LINE_SECONDS, "I thought I was going to pass out from a lack of oxygen. Like I was seeing stuff? It turns out that I wasn't holding my breath for too long." },
	{ LINE_SECONDS, "I was actually touching some kind of purple rock. Yeah. Purple. Rocks. Did you know stuff can actually grow on purple rocks?" },
	{ LINE_SECONDS, "And I don't mean like dirt and fungus. I mean actualy plants! At least it seemed to be a kind of plant. I'm not sure. Adventuring sure is amazing." },
	{ LINE_SECONDS, "You should try it some time. So I gathered as many sticks as I could and started to tape them together with some rope. Where did I get the rope?" },
	{ LINE_SECONDS, "I think I made it out of some sea plants. If you could go under water, you'd find all sorts of.. well, dangerous stuff. Don't do what I did." },
	{ LINE_SECONDS, "Stay on dry land. But, don't stay on purple land! I wanted to get gone and fast. That place was super creepy." },
	{ LONG_LINE_SECONDS, "I think I even saw, like, some kind of altar? I don't understand what it means. Maybe someone left it there? I tried touching it and it.." },
	{ LONG_LINE_SECONDS, "Wait, what was I talking about? Oh, yeah. I was at this party with some crabs. And.. uhh.. no, it was before that. Wasn't it?" },
	{ LONG_LINE_SECONDS, "I can't seem to remember.. How did I escape the..? Where was I when..? I don't feel-" },
	{ LONG_LINE_SECONDS, "Oh, right! I found these strange compasses out at sea.. somewhere. I don't know how I got them." },
	{ LONG_LINE_SECONDS, "I just kind of.. woke up and I had a whole crate full of these things. Man, my adventures really took me all over." },
	{ LONG_LINE_SECONDS, "Oh. But, listen to me just chatting your ear off. I got a habit of doing that. So, anyways!" },
}

return {
	Merchants = { TOKENS.AuraMerchant },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local CompassQuestService = Knit.GetService("CompassQuestService")
		local MonetizationService = Knit.GetService("MonetizationService")

		local tokens = Bind.data(scope, "CompassTokens.AuraBonus", 0)
		local rush = Bind.data(scope, "Shop.AuraCompass", 0)
		local goal = FruitEconomyConfig.GetAuraRushGoal()
		local line = scope:Value(1)
		local hasTokens = scope:Computed(function(use): boolean
			return (tonumber(use(tokens)) or 0) > 0
		end)

		local telling = true
		table.insert(scope, function()
			telling = false
		end)
		task.spawn(function()
			while telling do
				local index = Fusion.peek(line)
				task.wait(STORY[index][1])
				if telling then
					line:set(index % #STORY + 1)
				end
			end
		end)

		local claims: { any } = {}
		for order, amount in TOKENS.ClaimAmounts do
			table.insert(
				claims,
				Kit.Button(scope, {
					Name = `Claim{amount}`,
					LayoutOrder = order,
					Variant = "Blue",
					Size = UDim2.fromOffset(CLAIM_WIDTH, CLAIM_HEIGHT),
					Text = scope:Computed(function(use): string
						return if use(hasTokens) then `Claim {amount}` else `Buy {amount}`
					end),
					OnClick = function()
						if Fusion.peek(hasTokens) then
							CompassQuestService:ClaimAura(amount):catch(warn)
						else
							MonetizationService:Prompt(`Aura{amount}`):catch(warn)
						end
					end,
				})
			)
		end

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
							Name = "Shop",
							Text = "What A Great Friend",
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
										return STORY[use(line)][2]
									end),
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Tokens",
							Gap = Kit.Space.M,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, contentTop),
							Size = UDim2.new(1, middleWidth, 1, contentHeight),
							Children = {
								Kit.Label(scope, {
									Name = "TopLabel",
									LayoutOrder = 1,
									Text = scope:Computed(function(use): string
										return `Strange Compass Tokens: {use(tokens)}`
									end),
									Color = TOKEN_COLOR,
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.new(1, 0, 0, TOP_LABEL_HEIGHT),
								}),
								-- Only a picture (the old button did nothing either).
								Kit.Image(scope, {
									Name = "CompassButton",
									LayoutOrder = 2,
									Image = COMPASS_IMAGE,
									Size = UDim2.fromOffset(COMPASS_SIZE, COMPASS_SIZE),
									Transparency = scope:Computed(function(use): number
										return if use(hasTokens) then 0 else EMPTY_TRANSPARENCY
									end),
								}),
								Kit.Stack(scope, {
									Name = "Claims",
									LayoutOrder = 3,
									Direction = "Horizontal",
									Gap = Kit.Space.L,
									Children = claims,
								}),
								Kit.Label(scope, {
									Name = "LowerLabelWarning",
									LayoutOrder = 4,
									Text = WARNING,
									TextSize = Kit.TextSize.Small,
									Fit = true,
									-- What the three rows above leave of the column.
									Size = UDim2.new(
										1,
										0,
										1,
										-(TOP_LABEL_HEIGHT + COMPASS_SIZE + CLAIM_HEIGHT + 3 * Kit.Space.M)
									),
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Friend",
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
								Kit.Label(scope, {
									LayoutOrder = 2,
									Text = "Golden Aura Compass Progress",
									Color = GOLD_COLOR,
									TextSize = Kit.TextSize.Small,
									Fit = true,
									Size = UDim2.new(1, 0, 0, 26),
								}),
								Kit.Bar(scope, {
									Name = "GoldenCompassFrame",
									LayoutOrder = 3,
									Size = UDim2.new(1, 0, 0, 22),
									Color = GOLD_COLOR,
									BackColor = GAUGE_BACK,
									Value = scope:Computed(function(use): number
										return (tonumber(use(rush)) or 0) % goal / goal
									end),
								}),
								Kit.Label(scope, {
									Name = "Progress",
									LayoutOrder = 4,
									Text = scope:Computed(function(use): string
										return `{use(rush)} / {goal}`
									end),
									Color = GOLD_COLOR,
									TextSize = Kit.TextSize.Small,
									Fit = true,
									Size = UDim2.new(1, 0, 0, 26),
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
