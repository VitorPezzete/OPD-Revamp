--!strict
--[[
	Dialogue with Merlin the fisherman: take a delivery, watch his trust grow, buy the
	Super Rod.

	The screen sends two intents (MerlinService.TakePackage / BuySuperRod); requirements
	shown here are repeated on the server. While his cooldown runs he does not talk at
	all: the screen closes itself right away.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Dialogue = require(ReplicatedStorage.Client.UI.Components.Dialogue)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

type Scope = Theme.Scope

local SCREEN = "QuestFish"
local MERLIN = FishingConfig.Merlin
local COOLDOWN_ATTRIBUTE = "MerlinCooldownEnd"
local PORTRAIT = "rbxassetid://2724931472"
local SUPER_ROD_IMAGE = "rbxassetid://7242949418"

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

local ROD_PICTURE = 96

return {
	Merchants = { MERLIN.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local cooldownEnd = Players.LocalPlayer:GetAttribute(COOLDOWN_ATTRIBUTE)
		if type(cooldownEnd) == "number" and cooldownEnd > Workspace:GetServerTimeNow() then
			-- Nothing to show: an empty screen for the frame it takes to close.
			task.defer(context.Close)
			return UI.Screen(scope, { Name = SCREEN })
		end

		local MerlinService = Knit.GetService("MerlinService")
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

		-- Trust bar, hidden once he trusts the player completely.
		local trust = Bind.data(scope, "Fishing.MerlinTrust", 0)

		-- Super Rod offer.
		local offer = MERLIN.SuperRod
		local owned = Bind.data(scope, `Items.{offer.Item}`, false)
		local hasRequirement = Bind.data(scope, `Items.{offer.RequiredItem}`, false)
		local buying = scope:Value(false)

		local function buyRod()
			if Fusion.peek(owned) == true or Fusion.peek(buying) then
				return
			end
			buying:set(true)
			MerlinService:BuySuperRod():catch(warn):finally(function()
				buying:set(false)
			end)
		end

		return UI.Screen(scope, {
			Name = SCREEN,
			DisplayOrder = 10,
			Children = {
				Dialogue(scope, {
					Title = "Fishman Fisherman",
					Speaker = "Merlin",
					Portrait = PORTRAIT,
					Text = text,
					Size = UDim2.fromOffset(820, 450),
					SpeechHeight = 200,
					Actions = {
						UI.Button(scope, {
							Name = "Accept",
							Text = buttonText,
							Size = UDim2.fromOffset(160, 40),
							OnClick = advance,
						}),
					},
					Children = {
						UI.Panel(scope, {
							Name = "Trust",
							Size = UDim2.new(0.5, -Theme.Space.S, 1, 0),
							Padding = Theme.Space.M,
							Visible = scope:Computed(function(use)
								return use(trust) < MERLIN.TrustGoal
							end),
							Children = {
								UI.Label(scope, {
									Name = "Title",
									Text = "Merlin's Trust",
									Variant = "BodyBold",
									TextXAlignment = Enum.TextXAlignment.Left,
									Size = UDim2.new(1, 0, 0, 24),
								}),
								UI.Label(scope, {
									Name = "Hint",
									Text = "Every delivery earns a little more of it.",
									Variant = "Small",
									Wrapped = true,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextYAlignment = Enum.TextYAlignment.Top,
									Position = UDim2.fromOffset(0, 28),
									Size = UDim2.new(1, 0, 0, 40),
								}),
								UI.ProgressBar(scope, {
									Name = "Progress",
									Value = scope:Computed(function(use)
										return use(trust) / MERLIN.TrustGoal
									end),
									Text = scope:Computed(function(use)
										return `{use(trust)} / {MERLIN.TrustGoal}`
									end),
									Color = Theme.Colors.Beri,
									AnchorPoint = Vector2.new(0, 1),
									Position = UDim2.fromScale(0, 1),
									Size = UDim2.new(1, 0, 0, 26),
								}),
							},
						}),
						UI.Panel(scope, {
							Name = "SuperRod",
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.new(0.5, -Theme.Space.S, 1, 0),
							Padding = Theme.Space.M,
							Children = {
								UI.Image(scope, {
									Name = "Pic",
									Image = SUPER_ROD_IMAGE,
									Size = UDim2.fromOffset(ROD_PICTURE, ROD_PICTURE),
									Background = Theme.Colors.Sunken,
									Radius = Theme.Radius.Small,
								}),
								UI.Label(scope, {
									Name = "LabelName",
									Text = offer.Item,
									Variant = "Heading",
									TextXAlignment = Enum.TextXAlignment.Left,
									Position = UDim2.fromOffset(ROD_PICTURE + Theme.Space.M, 0),
									Size = UDim2.new(1, -(ROD_PICTURE + Theme.Space.M), 0, 28),
								}),
								UI.Button(scope, {
									Name = "Accept",
									Text = scope:Computed(function(use): string
										if use(owned) == true then
											return "Owned"
										elseif use(hasRequirement) ~= true then
											return `Requirement: {offer.RequiredItem}`
										end
										return `${Bind.formatNumber(offer.Price)}`
									end),
									TextSize = Theme.TextSize.Small,
									Variant = "Secondary",
									TextColor = Theme.Colors.Beri,
									Disabled = scope:Computed(function(use)
										return use(owned) == true or use(buying)
									end),
									AnchorPoint = Vector2.new(1, 1),
									Position = UDim2.fromScale(1, 1),
									Size = UDim2.new(1, -(ROD_PICTURE + Theme.Space.M), 0, 44),
									OnClick = buyRod,
								}),
							},
						}),
					},
				}),
			},
		})
	end,
}
