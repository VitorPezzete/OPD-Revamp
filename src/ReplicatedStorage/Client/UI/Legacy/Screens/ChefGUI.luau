--!strict
--[[
	Dialogue with the chef (legacy ChefGUI): one line of small talk, then "Sell All Fish".
	The sale itself is FishingService.SellFish: the server prices the fish it handed out.

	The old orange board with its turquoise sheet: what the chef says in the dark box on
	the left with the button under it, his portrait and name on the right.

	Legacy bug fixed: the "you need a rod first" lines looked for an item called
	"Own_WoodRod" (no space), which never existed, so they were never shown.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)

type Scope = Fusion.Scope<typeof(Fusion)>

local OUTER_COLOR = Color3.fromRGB(221, 83, 36)
local INNER_COLOR = Color3.fromRGB(36, 221, 193)
local PORTRAIT_IMAGE = "rbxassetid://5373319844"

-- Design pixels. The old board took 0.7 of the screen each way.
local WINDOW_SIZE = Vector2.new(1280, 680)
local FRAME_MARGIN = 30
local TITLE_HEIGHT = 56
local PORTRAIT_SIZE = 238
local SIDE_WIDTH = 300
local NAME_HEIGHT = 40
local BUTTON_SIZE = Vector2.new(320, 52)

local NO_ROD_GREETING =
	"I'm not sure if you're equipped with the right tools for this job. Why don't you go find Merlin and see if he has work for you? He might introduce you to the fishing business."
local NO_ROD_OFFER =
	"You got some fish? All you need is a fishing rod to get started. Even if you do have some fish, I'm not buying random fish from someone without a fishing rod. Who knows where those fish came from? Not from you, that's for sure. So go talk to Merlin."

local GREETINGS = {
	"You didn't come to the wrong place, I'm just waiting for another delivery. Why are those deliveries taking so long? I gave the captain an extra Lubber for dinner!",
	"I was bitten by a snake. No, you don't need to help with the venom. I just ate the snake. Now I'll have all the venom, and he won't have any! Time to bite some snakes. Revenge!",
	"I still get nightmares about that day. The war affected us all. The water our men had to drink was so filthy that we just ate charcoal all day. Can't get food poisoning if what you're eating isn't technically food.",
	"You're not a health inspector, right? ... Ok, good. In other news, we don't have a kitchen sink to wash our hands and the rats have learned the key code to our safe. (1234 is written on a note nearby.)",
	"I peel the onions to make them cry. No, not the customers. The onions! They feel pain and I'm going to prove it. Grab a knife and help.",
	"Do not touch the fire extinguisher! I filled it with gasoline! Nobody is gonna take my fire away from me. Not again!",
	"If I punch this coal really hard, then I can make diamonds. I'll sell them at 10,000% market value and get rich! The first thing I'm going to buy is some stronger rat poison. They're the toughest in the world. The rats, I mean. Not the diamonds.",
}

local OFFERS = {
	"You got some fish for me this time? Or are you just gonna plunder my crates again? I've got cash if you've got fish to trade. How about it?",
	"My customers are hungry. I mean. They would be, if I had customers. Wait, no. They wouldn't be hungry because.. Uhg. Just sell me some fish before I get mad.",
	"You a pirate? Don't pirates steal things? You stay out of my crates! Filthy thieves. Just sell me some fish and leave!",
	"Flubber, blubber, rubber.. ah, I can't remember all these names. If it quacks like a fish, walks like a fish, sings like a fish, then you gotta sell it to me.",
	"Have you been cooking those fish? It'd save me a lot of trouble to just buy them already cooked. Sell me some cooked fish, yeah?",
	"I'll show you how sharp my fillet knife is if you sell me some fish. You can't tell anyone what I show you, though. Top secret.",
}

return {
	Merchants = { FishingConfig.ChefMerchant },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		MerchantDialogue.closeOnMove(scope, context.Close)

		local hasRod = Knit.GetController("DataController"):Get(`Items.{FishingConfig.Merlin.FirstDeliveryItem}`) == true
		local text = scope:Value(if hasRod then MerchantDialogue.pick(GREETINGS) else NO_ROD_GREETING)
		local buttonText = scope:Value("Next")

		local offered = false
		local function advance()
			if not offered then
				offered = true
				text:set(if hasRod then MerchantDialogue.pick(OFFERS) else NO_ROD_OFFER)
				buttonText:set("Sell All Fish")
				return
			end

			context.Close()
			Knit.GetService("FishingService"):SellFish():catch(warn)
		end

		local contentTop = TITLE_HEIGHT + Kit.Space.S
		-- Under the dialogue: the button, then the hint.
		local footer = Kit.Space.M + BUTTON_SIZE.Y + Kit.Space.S + ShopScreen.HINT_HEIGHT
		local dialogueWidth = -(SIDE_WIDTH + Kit.Space.XL)

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
							Text = "Fish Merchant",
							TextSize = Kit.TextSize.Title,
							Fit = true,
							Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
						}),

						Kit.Well(scope, {
							Name = "Dia",
							Transparency = 0.7,
							Padding = Kit.Space.L,
							Position = UDim2.fromOffset(0, contentTop),
							Size = UDim2.new(1, dialogueWidth, 1, -(contentTop + footer)),
							Children = {
								Kit.Label(scope, {
									Text = text,
									TextSize = Kit.TextSize.Title,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),
						-- Centred under the dialogue box, not under the whole sheet.
						scope:New("Frame")({
							Name = "Actions",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0, 1),
							Position = UDim2.new(0, 0, 1, -(Kit.Space.S + ShopScreen.HINT_HEIGHT)),
							Size = UDim2.new(1, dialogueWidth, 0, BUTTON_SIZE.Y),
							[Fusion.Children] = {
								Kit.Button(scope, {
									Name = "Accept",
									Variant = "Blue",
									Text = buttonText,
									AnchorPoint = Vector2.new(0.5, 0),
									Position = UDim2.fromScale(0.5, 0),
									Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
									OnClick = advance,
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Chef",
							Gap = Kit.Space.XS,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, contentTop),
							Size = UDim2.new(0, SIDE_WIDTH, 1, -(contentTop + footer)),
							Children = {
								Kit.Label(scope, {
									Name = "LabelName",
									LayoutOrder = 1,
									Text = "Chef",
									TextSize = Kit.TextSize.Heading,
									Size = UDim2.new(1, 0, 0, NAME_HEIGHT),
								}),
								Kit.Image(scope, {
									Name = "Portrait",
									LayoutOrder = 2,
									Image = PORTRAIT_IMAGE,
									Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE),
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

		return Kit.Screen(scope, {
			Name = context.Name,
			Children = { window },
		})
	end,
}
