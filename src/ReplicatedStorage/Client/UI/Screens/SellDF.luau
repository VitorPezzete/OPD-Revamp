--!strict
--[[
	SellerMerchant: sell the held fruit, or spend DF coins in his small shop.

	"Sell Fruit" asks the server what it offers for the fruit in hand and shows the
	offer (Beri only, or Beri / Gems / DF Coins for rare fruits). Picking a currency
	sends just that; the server sells whatever is held at that moment.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local HeldTool = require(ReplicatedStorage.Client.UI.Util.HeldTool)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)
local MerchantSpeech = require(ReplicatedStorage.Client.UI.Components.MerchantSpeech)
local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

type Scope = Theme.Scope
type Quote = { Fruit: string, Beri: number, Gems: number?, DFCoins: number? }

local SELLER = FruitEconomyConfig.Seller
-- Set by FruitService on every fruit Tool.
local FRUIT_ATTRIBUTE = "FruitItem"

local PORTRAIT = "rbxassetid://87689754045368"
local BERI_ICON = "rbxassetid://125727494661544"
local GEM_ICON = "rbxassetid://1954296071"
local COIN_ICON = "rbxassetid://133384158118895"
local REMOVE_FRUIT_ICON = "rbxassetid://79652690003957"
local GOLDEN_COMPASS_ICON = "rbxassetid://130920061244370"

local GREETING =
	"Hey there, got some fruits to sell? I'm a suspicious guy, so im only buying fruits found by you."
local SHOP_GREETING = "Got DF coins? Hover an item to see what it does."

local SPEECH_HEIGHT = 140
local AREA_HEIGHT = 168
local BUTTON_HEIGHT = 50
local HINT_HEIGHT = 22
local GAP = Theme.Space.M
local CARD_WIDTH = 150
local OFFER_BUTTON_WIDTH = 170

-- Currency key of a Quote -> text after the amount, icon.
local CURRENCIES: { { string } } = {
	{ "Beri", "Beri", BERI_ICON },
	{ "Gems", "Gems", GEM_ICON },
	{ "DFCoins", "DFCoins", COIN_ICON },
}

return {
	Merchants = { SELLER.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any)
		local FruitTradeService = Knit.GetService("FruitTradeService")

		local inShop = scope:Value(false)
		local quote: Fusion.Value<Quote?> = scope:Value(nil :: Quote?)
		local quoting = scope:Value(false)
		local dfCoins = Bind.data(scope :: any, "Economy.DFCoins", 0)
		local compassPrice = scope:Value(SELLER.GoldenCompassCoins)
		local description = scope:Value("")
		local closed = false
		table.insert(scope, function()
			closed = true
		end)

		local held = HeldTool.observe(scope :: any)
		local holding = scope:Computed(function(use): boolean
			local tool = use(held)
			return tool ~= nil and tool:GetAttribute(FRUIT_ATTRIBUTE) ~= nil
		end)
		-- An offer is for the fruit that was in hand when it was made.
		scope:Observer(held):onChange(function()
			quote:set(nil)
		end)

		local hasQuote = scope:Computed(function(use): boolean
			return use(quote) ~= nil
		end)
		local notInShop = scope:Computed(function(use): boolean
			return not use(inShop)
		end)

		local function sell(currency: string)
			quote:set(nil)
			FruitTradeService:Sell(currency):catch(warn)
		end

		-- Common and Uncommon fruits only sell for Beri: the other two buttons need a gem offer.
		local offers: { any } = {}
		for index, currency in CURRENCIES do
			local key, suffix, icon = currency[1], currency[2], currency[3]
			offers[index] = UI.Button(scope, {
				Name = key,
				LayoutOrder = index,
				Icon = icon,
				IconColor = Theme.Colors.TextOnPrimary,
				Variant = "Secondary",
				Size = UDim2.fromOffset(OFFER_BUTTON_WIDTH, BUTTON_HEIGHT - 6),
				TextSize = Theme.TextSize.Small,
				Text = scope:Computed(function(use): string
					local offer: any = use(quote)
					local amount = offer and offer[key]
					return if amount then `{amount} {suffix}` else `.. {suffix}`
				end),
				Visible = scope:Computed(function(use): boolean
					local offer = use(quote)
					return key == "Beri" or (offer ~= nil and offer.Gems ~= nil)
				end),
				OnClick = function()
					sell(key)
				end,
			})
		end

		ShopWindow.closeOnMove(scope, context)

		local areaTop = SPEECH_HEIGHT + GAP
		local bodyHeight = areaTop + AREA_HEIGHT + Theme.Space.S + HINT_HEIGHT

		return UI.Screen(scope, {
			Name = "SellDF",
			Children = UI.Window(scope, {
				Title = "Suspicious Man From Quest Land",
				Subtitle = scope:Computed(function(use): string
					return `DF Coins: {use(dfCoins)}`
				end),
				Size = UDim2.fromOffset(760, 52 + Theme.Space.L * 2 + bodyHeight),
				Children = {
					MerchantSpeech(scope, {
						Portrait = PORTRAIT,
						Text = scope:Computed(function(use): string
							if not use(inShop) then
								return GREETING
							end
							local text = use(description)
							return if text == "" then SHOP_GREETING else text
						end),
						Height = SPEECH_HEIGHT,
					}),

					-- Selling.
					scope:New("Frame")({
						Name = "Frame",
						Position = UDim2.fromOffset(0, areaTop),
						Size = UDim2.new(1, 0, 0, AREA_HEIGHT),
						BackgroundTransparency = 1,
						Visible = notInShop,
						[Fusion.Children] = {
							UI.Button(scope, {
								Name = "Sell",
								Text = "Sell Fruit",
								Variant = scope:Computed(function(use): any
									return if use(holding) then "Primary" else "Secondary"
								end),
								Disabled = quoting,
								Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
								OnClick = function()
									quoting:set(true)
									FruitTradeService:GetQuote()
										:andThen(function(offer: Quote?)
											if not closed then
												quote:set(offer)
											end
										end)
										:catch(warn)
										:finally(function()
											if not closed then
												quoting:set(false)
											end
										end)
								end,
							}),
							UI.Button(scope, {
								Name = "Shop",
								Text = "Shop",
								Variant = "Secondary",
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.fromScale(1, 0),
								Size = UDim2.new(0.5, -Theme.Space.S / 2, 0, BUTTON_HEIGHT),
								OnClick = function()
									quote:set(nil)
									description:set("")
									inShop:set(true)
									FruitTradeService:GetGoldenCompassPrice()
										:andThen(function(price: number)
											if not closed and type(price) == "number" then
												compassPrice:set(price)
											end
										end)
										:catch(warn)
								end,
							}),

							UI.Panel(scope, {
								Name = "Offer",
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT + GAP)),
								Padding = Theme.Space.M,
								Visible = hasQuote,
								Children = {
									UI.Label(scope, {
										Name = "Title",
										Text = scope:Computed(function(use): string
											local offer = use(quote)
											return if offer and type(offer.Fruit) == "string"
												then `Offer for {offer.Fruit}. Sell it for:`
												else "Sell it for:"
										end),
										Variant = "Small",
										TextXAlignment = Enum.TextXAlignment.Left,
										TextTruncate = Enum.TextTruncate.AtEnd,
										Size = UDim2.new(1, -44, 0, 22),
									}),
									UI.Button(scope, {
										Name = "Close",
										Text = "X",
										Variant = "Ghost",
										AnchorPoint = Vector2.new(1, 0),
										Position = UDim2.new(1, 0, 0, -4),
										Size = UDim2.fromOffset(32, 32),
										OnClick = function()
											quote:set(nil)
										end,
									}),
									UI.Stack(scope, {
										Name = "Currencies",
										Direction = "Horizontal",
										Gap = Theme.Space.S,
										AnchorPoint = Vector2.new(0, 1),
										Position = UDim2.fromScale(0, 1),
										Children = offers,
									}),
								},
							}),
						},
					}),

					-- The DF coin shop.
					scope:New("Frame")({
						Name = "Shop",
						Position = UDim2.fromOffset(0, areaTop),
						Size = UDim2.new(1, 0, 0, AREA_HEIGHT),
						BackgroundTransparency = 1,
						Visible = inShop,
						[Fusion.Children] = {
							UI.Card(scope, {
								Name = "RemoveDF",
								Title = "Remove Fruit",
								Caption = `{SELLER.RemoveFruitCoins} DF Coins`,
								CaptionColor = Theme.Colors.Warning,
								Image = REMOVE_FRUIT_ICON,
								Size = UDim2.new(0, CARD_WIDTH, 1, 0),
								OnClick = function()
									FruitTradeService:RemoveFruit():catch(warn)
								end,
								OnHover = function(hovering: boolean)
									if hovering then
										description:set(
											`Remove your first devil fruit. Costs {SELLER.RemoveFruitCoins} DFCoins`
										)
									end
								end,
							}),
							UI.Card(scope, {
								Name = "GoldenCompass",
								Title = "Golden Compass",
								Caption = scope:Computed(function(use): string
									return `{use(compassPrice)} DF Coins`
								end),
								CaptionColor = Theme.Colors.Warning,
								Image = GOLDEN_COMPASS_ICON,
								Position = UDim2.fromOffset(CARD_WIDTH + GAP, 0),
								Size = UDim2.new(0, CARD_WIDTH, 1, 0),
								OnClick = function()
									FruitTradeService:BuyGoldenCompass():catch(warn)
								end,
								OnHover = function(hovering: boolean)
									if hovering then
										description:set(
											"A special compass made of pure gold. Has 80% chance of a Rare Box and 20% chance of a Ultra Rare Box. "
												.. `Costs {Fusion.peek(compassPrice)} DFCoins`
										)
									end
								end,
							}),

							UI.Image(scope, {
								Name = "CoinIcon",
								Image = COIN_ICON,
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.new(1, -150, 0, 0),
								Size = UDim2.fromOffset(40, 40),
							}),
							UI.Label(scope, {
								Name = "DFCoins",
								Text = scope:Computed(function(use): string
									return tostring(use(dfCoins))
								end),
								Variant = "Title",
								Color = Theme.Colors.Warning,
								TextXAlignment = Enum.TextXAlignment.Left,
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.fromScale(1, 0),
								Size = UDim2.fromOffset(140, 40),
								Scaled = true,
							}),
							UI.Button(scope, {
								Name = "Back",
								Text = "Back",
								Variant = "Secondary",
								AnchorPoint = Vector2.new(1, 1),
								Position = UDim2.fromScale(1, 1),
								Size = UDim2.fromOffset(190, BUTTON_HEIGHT),
								OnClick = function()
									inShop:set(false)
								end,
							}),
						},
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
