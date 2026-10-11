--!strict
--[[
	Dialogue with Merlin the fisherman (legacy QuestFish): take a delivery, watch his
	trust grow, buy the Super Rod.

	The old blue and green dialogue window, "Fishman Fisherman" across the top, in three
	columns: the Super Rod with its price button at the left, what he says and the answer
	button in the middle, his picture, his name and the trust gauge at the right. (The old
	Super Rod picture lay half over the speech box.)

	The screen sends two intents (MerlinService.TakePackage / BuySuperRod); requirements
	shown here are repeated on the server. While his cooldown runs he does not talk at
	all, as before: the screen closes itself right away.

	Legacy bug fixed: the opening line was only picked when the character moved (which
	also closed the window), so everyone always read the first-time introduction.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local DialogueBox = require(ReplicatedStorage.Client.UI.Legacy.Components.DialogueBox)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)

type Scope = Fusion.Scope<typeof(Fusion)>

local SCREEN = "QuestFish"
local MERLIN = FishingConfig.Merlin
local COOLDOWN_ATTRIBUTE = "MerlinCooldownEnd"
local DISPLAY_ORDER = 10

local OUTER_COLOR = Color3.fromRGB(22, 162, 221)
local INNER_COLOR = Color3.fromRGB(21, 221, 128)
local PORTRAIT = "rbxassetid://2724931472"
local SUPER_ROD = "rbxassetid://7242949418"
-- The blue of the old trust gauge.
local TRUST_COLOR = Color3.fromRGB(14, 38, 255)

local SIDE_WIDTH = 280
local ROD_SIDE = 220
local NAME_HEIGHT = 44
local BUTTON_SIZE = UDim2.fromOffset(340, 64)
local BUY_SIZE = UDim2.fromOffset(SIDE_WIDTH, 52)
local TRUST_SIZE = UDim2.fromOffset(SIDE_WIDTH, 26)

local NO_ROD_GREETING =
	"Fishing isn't a hobby, it's a way of life! You look like you might enjoy it, but I'm not sure if you're ready to be a fishing master. How about you help me out and I'll give you one of my old rods?"
local NO_ROD_OFFER =
	"All I need you to do is deliver some fish for me. I've got the shipment right here. Make the delivery and I'll give you a reward! Come back for more deliveries."

local GREETINGS = {
	"Hey friend! Are you here to do another delivery for me? Sure thing! Always happy to have some help.",
	"Welcome back! I hope you didn't drop the box in the sea or something. Those packages cost money!",
	"I've got so many fish, it might be easier just to dump them in the sea! Good thing the customers don't know that, or they might expect a better price. Hey, don't go telling anyone I said that!",
	"You wouldn't believe me if I told you, but I'll say it anyways. I saw someone shooting fire out of their hands! FIRE! Can you believe it?",
	"OH! You surprised me. I thought I saw a ghost. Strangest thing!",
	"What's the darkest thing you've ever seen? I once saw a crow!",
	"I wonder what's taking my delivery so long? Whatever. I'm sure I'll find someone more qualified to deliver packages than that guy. What's that? You're here to steal my delivery boy's job?",
}

local OFFERS = {
	"Make sure to thank the customer for their patronage!",
	"It's good to see hard working people like yourself. The last guy I got to deliver these for me left the box in a hole! I ended up finding it again, though. Now you get to deliver it!",
	"How long have you been a privateer? Wait.. you're not a pirate, are you? Well, it's still better than the last guy I had. Just don't shake the box. OK?",
	"Where are my manners? My name is Merlin. Now take this box and don't look inside. ",
	"Statisticly speaking.. There's no way you're going to deliver this box. (I wonder if reverse psychology actually works?) ",
	"I used to be a privateer like you. But, then I found a fishing rod. Long story short, take this box and run. ",
	"I heard there's a monster around here! You should take this package and deliver it fast, before it catches you! ",
	"One box per customer, one box per delivery. If I gave out all my packages at once and something happened, I'd lose a fortune! Although, I just spend all my money on smoothies.. Just take the package and go.",
}

return {
	Merchants = { MERLIN.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local cooldownEnd = Players.LocalPlayer:GetAttribute(COOLDOWN_ATTRIBUTE)
		if type(cooldownEnd) == "number" and cooldownEnd > Workspace:GetServerTimeNow() then
			-- Nothing to show for the frame it takes to close.
			task.defer(context.Close)
			return Kit.Screen(scope, { Name = SCREEN, DisplayOrder = DISPLAY_ORDER })
		end

		local MerlinService = Knit.GetService("MerlinService")

		-- Closes when the player walks away, dies or has no character.
		MerchantDialogue.closeOnMove(scope, context.Close)

		local hasRod = Knit.GetController("DataController"):Get(`Items.{MERLIN.FirstDeliveryItem}`) == true
		local text = scope:Value(if hasRod then MerchantDialogue.pick(GREETINGS) else NO_ROD_GREETING)
		local buttonText = scope:Value("Next")

		local offered = false
		local function advance()
			if not offered then
				offered = true
				text:set(if hasRod then MerchantDialogue.pick(OFFERS) else NO_ROD_OFFER)
				buttonText:set("Accept")
				return
			end

			context.Close()
			MerlinService:TakePackage():catch(warn)
		end

		local trust = Bind.data(scope, "Fishing.MerlinTrust", 0)

		-- Super Rod offer.
		local offer = MERLIN.SuperRod
		local owned = Bind.data(scope, `Items.{offer.Item}`, false)
		local hasRequirement = Bind.data(scope, `Items.{offer.RequiredItem}`, false)
		local buying = scope:Value(false)

		local function buy()
			if Fusion.peek(owned) == true or Fusion.peek(buying) then
				return
			end
			buying:set(true)
			MerlinService:BuySuperRod():catch(warn):finally(function()
				buying:set(false)
			end)
		end

		local column = SIDE_WIDTH + Kit.Space.XL
		local buttonRow = BUTTON_SIZE.Y.Offset + Kit.Space.L

		return Kit.Screen(scope, {
			Name = SCREEN,
			DisplayOrder = DISPLAY_ORDER,
			Children = {
				-- A window for the gamepad; like the rework's dialogue it has no close button.
				DialogueBox.new(scope, {
					Title = "Fishman Fisherman",
					Color = OUTER_COLOR,
					InnerColor = INNER_COLOR,
					Children = {
						Kit.Stack(scope, {
							Name = "Pic",
							Gap = Kit.Space.S,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(0, SIDE_WIDTH / 2, 0.5, 0),
							Children = {
								Kit.Label(scope, {
									Name = "LabelName",
									Text = offer.Item,
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.fromOffset(SIDE_WIDTH, NAME_HEIGHT),
									LayoutOrder = 1,
								}),
								Kit.Image(scope, {
									Name = "Picture",
									Image = SUPER_ROD,
									Size = UDim2.fromOffset(ROD_SIDE, ROD_SIDE),
									LayoutOrder = 2,
								}),
								Kit.Button(scope, {
									Name = "Accept",
									Variant = "Blue",
									Size = BUY_SIZE,
									LayoutOrder = 3,
									-- Greyed out once owned and while a purchase is on its way.
									Disabled = scope:Computed(function(use): boolean
										return use(owned) == true or use(buying)
									end),
									Text = scope:Computed(function(use): string
										if use(owned) == true then
											return "Owned"
										elseif use(hasRequirement) ~= true then
											return `Requirement: {offer.RequiredItem}`
										end
										return `${Bind.formatNumber(offer.Price)}`
									end),
									OnClick = buy,
								}),
							},
						}),

						DialogueBox.speech(scope, {
							Text = text,
							Position = UDim2.fromOffset(column, 0),
							Size = UDim2.new(1, -2 * column, 1, -buttonRow),
						}),
						Kit.Button(scope, {
							Name = "Next",
							Text = buttonText,
							Variant = "Blue",
							TextSize = Kit.TextSize.Heading,
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.fromScale(0.5, 1),
							Size = BUTTON_SIZE,
							OnClick = advance,
						}),

						Kit.Stack(scope, {
							Name = "Merlin",
							Gap = Kit.Space.L,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.new(1, -SIDE_WIDTH / 2, 0.5, 0),
							Children = {
								DialogueBox.portrait(scope, {
									Image = PORTRAIT,
									Speaker = "Merlin",
									LayoutOrder = 1,
								}),
								-- Trust gauge, hidden once he trusts the player completely.
								Kit.Stack(scope, {
									Name = "GoldenCompassFrame",
									Gap = Kit.Space.XS,
									HorizontalAlignment = Enum.HorizontalAlignment.Center,
									LayoutOrder = 2,
									Visible = scope:Computed(function(use): boolean
										return use(trust) < MERLIN.TrustGoal
									end),
									Children = {
										Kit.Label(scope, {
											Name = "Title",
											Text = "Merlin's Trust",
											TextSize = Kit.TextSize.Small,
											LayoutOrder = 1,
										}),
										Kit.Bar(scope, {
											Name = "Progress",
											Size = TRUST_SIZE,
											Color = TRUST_COLOR,
											LayoutOrder = 2,
											Value = scope:Computed(function(use): number
												return use(trust) / MERLIN.TrustGoal
											end),
											Text = scope:Computed(function(use): string
												return `{use(trust)} / {MERLIN.TrustGoal}`
											end),
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
