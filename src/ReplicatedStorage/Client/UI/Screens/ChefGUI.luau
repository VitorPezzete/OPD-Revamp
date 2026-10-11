--!strict
--[[
	Dialogue with the chef: one line of small talk, then "Sell All Fish".
	The sale itself is FishingService.SellFish: the server prices the fish it handed out.
	Without the first rod the chef sends the player to Merlin instead.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MerchantSpeech = require(ReplicatedStorage.Client.UI.Components.MerchantSpeech)
local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

type Scope = Theme.Scope

local PORTRAIT = "rbxassetid://5373319844"
local SPEECH_HEIGHT = 190
local BUTTON_HEIGHT = 52
local HINT_HEIGHT = 22

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

	Mount = function(scope: Scope, _gui: any, context: any)
		MerchantDialogue.closeOnMove(scope :: any, function()
			context.Close()
		end)

		local hasRod = Knit.GetController("DataController"):Get(`Items.{FishingConfig.Merlin.FirstDeliveryItem}`) == true
		local text = scope:Value(if hasRod then MerchantDialogue.pick(GREETINGS) else NO_ROD_GREETING)
		local offered = scope:Value(false)

		local bodyHeight = SPEECH_HEIGHT + Theme.Space.M + BUTTON_HEIGHT + Theme.Space.S + HINT_HEIGHT

		return UI.Screen(scope, {
			Name = "ChefGUI",
			Children = UI.Window(scope, {
				Title = "Fish Merchant",
				Size = UDim2.fromOffset(720, 52 + Theme.Space.L * 2 + bodyHeight),
				Children = {
					MerchantSpeech(scope, {
						Portrait = PORTRAIT,
						Speaker = "Chef",
						Text = text,
						Height = SPEECH_HEIGHT,
					}),
					UI.Button(scope, {
						Name = "Accept",
						Text = scope:Computed(function(use): string
							return if use(offered) then "Sell All Fish" else "Next"
						end),
						Variant = scope:Computed(function(use): any
							return if use(offered) then "Success" else "Primary"
						end),
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, 0, 0, SPEECH_HEIGHT + Theme.Space.M),
						Size = UDim2.fromOffset(240, BUTTON_HEIGHT),
						OnClick = function()
							if not Fusion.peek(offered) then
								offered:set(true)
								text:set(if hasRod then MerchantDialogue.pick(OFFERS) else NO_ROD_OFFER)
								return
							end

							context.Close()
							Knit.GetService("FishingService"):SellFish():catch(warn)
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
