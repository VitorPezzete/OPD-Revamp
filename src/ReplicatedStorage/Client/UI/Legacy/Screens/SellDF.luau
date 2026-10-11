--!strict
--[[
	SellerMerchant: sell the held fruit, or spend DF coins in his small shop.

	"Sell Fruit" asks the server what it offers for the fruit in hand and shows the offer
	card (Beri only, or Beri / Gems / DF Coins for rare fruits). Picking a currency sends
	just that; the server sells whatever is held at that moment.

	The old purple boards. Selling page: what the man says on the left, the offer card and
	"Sell Fruit" in the middle, his portrait over "Shop" on the right. Shop page: the two
	items in a column with their price in DF coins, the description box beside them, the
	coins at the top right. The old shop page had no way back and its offer panels did not
	say which fruit they were for: the Back button and the card's title line stay.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local HeldTool = require(ReplicatedStorage.Client.UI.Util.HeldTool)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)

type Scope = Fusion.Scope<typeof(Fusion)>
type Quote = { Fruit: string, Beri: number, Gems: number?, DFCoins: number? }

local SELLER = FruitEconomyConfig.Seller
-- Set by FruitService on every fruit Tool.
local FRUIT_ATTRIBUTE = "FruitItem"
local SHOP_GREETING = "Got DF coins? Hover an item to see what it does."
local GREETING = "Hey there, got some fruits to sell? I'm a suspicious guy, so im only buying fruits found by you."

local BOARD_COLOR = Color3.fromRGB(119, 30, 221)
local PURPLE_BUTTON = Color3.fromRGB(116, 43, 158)
local COINS_COLOR = Color3.fromRGB(236, 26, 255)
local NPC_IMAGE = "rbxassetid://87689754045368"
local COIN_IMAGE = "rbxassetid://133384158118895"
local REMOVE_IMAGE = "rbxassetid://79652690003957"
local COMPASS_IMAGE = "rbxassetid://130920061244370"

-- What an offer can be paid in: { quote field, suffix, picture, colour of the amount }.
local CURRENCIES: { { any } } = {
	{ "Beri", "Beri", "rbxassetid://125727494661544", Color3.fromRGB(255, 255, 52) },
	{ "Gems", "Gems", "rbxassetid://1954296071", Color3.fromRGB(35, 237, 255) },
	{ "DFCoins", "DFCoins", COIN_IMAGE, COINS_COLOR },
}

-- Design pixels. The old boards were 1.2 x 0.6 and 0.9 x 0.7 of the screen's height.
local MAIN_SIZE = Vector2.new(1220, 620)
local SHOP_SIZE = Vector2.new(920, 640)
local FRAME_MARGIN = 30
local TITLE_HEIGHT = 56
local SIDE_WIDTH = 300
local PORTRAIT_SIZE = 250
local BUTTON_SIZE = Vector2.new(260, 52)
local CARD_HEIGHT = 280
local CARD_HEADER = 40
local CURRENCY_SIZE = Vector2.new(130, 120)
local AMOUNT_HEIGHT = 34
local ITEM_SIZE = 124
local PRICE_HEIGHT = 32
local ITEMS_WIDTH = 160
local COINS_SIZE = Vector2.new(170, 44)

-- The purple button of this merchant (Shop, Back): no Kit variant has its colour.
local function purpleButton(scope: Scope, props: Kit.Layout & { Text: string, OnClick: () -> () }): Instance
	return Kit.Well(scope, {
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size or UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
		Color = PURPLE_BUTTON,
		Transparency = 0,
		Children = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			Kit.Button(scope, {
				Variant = "Ghost",
				Text = props.Text,
				Size = UDim2.fromScale(1, 1),
				OnClick = props.OnClick,
			}),
		},
	})
end

-- An amount of DF coins with the coin after it.
local function coins(scope: Scope, props: Kit.Layout & { Text: Fusion.UsedAs<string>, TextSize: number? }): Instance
	local height = (props.Size :: any).Y.Offset
	return scope:New("Frame")({
		Name = props.Name or "Coins",
		LayoutOrder = props.LayoutOrder,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		[Fusion.Children] = {
			Kit.Label(scope, {
				Text = props.Text,
				Color = COINS_COLOR,
				TextSize = props.TextSize or Kit.TextSize.Body,
				Fit = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(1, -(height + Kit.Space.XS), 1, 0),
			}),
			Kit.Image(scope, {
				Image = COIN_IMAGE,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(height, height),
			}),
		},
	})
end

return {
	Merchants = { SELLER.Merchant },

	Mount = function(scope: Scope, _gui: any, context: any): ScreenGui
		local FruitTradeService = Knit.GetService("FruitTradeService")

		local inShop = scope:Value(false)
		local quote: Fusion.Value<Quote?> = scope:Value(nil :: Quote?)
		local dfCoins = Bind.data(scope, "Economy.DFCoins", 0)
		local compassPrice = scope:Value(SELLER.GoldenCompassCoins)
		local description = scope:Value("")
		local quoting = scope:Value(false)
		local closed = false
		table.insert(scope, function()
			closed = true
		end)

		local held = HeldTool.observe(scope)
		local holding = scope:Computed(function(use): boolean
			local tool = use(held)
			return tool ~= nil and tool:GetAttribute(FRUIT_ATTRIBUTE) ~= nil
		end)
		-- An offer is for the fruit that was in hand when it was made.
		scope:Observer(held):onChange(function()
			quote:set(nil)
		end)

		local gui: ScreenGui
		-- The page under the selection changed: the gamepad follows.
		local function refocus()
			ShopScreen.focus(scope, gui)
		end

		local function requestQuote()
			-- One quote at a time.
			if Fusion.peek(quoting) then
				return
			end
			quoting:set(true)
			FruitTradeService:GetQuote()
				:andThen(function(offer: Quote?)
					if not closed then
						quote:set(offer)
						refocus()
					end
				end)
				:catch(warn)
				:finally(function()
					if not closed then
						quoting:set(false)
					end
				end)
		end

		local function sell(currency: string)
			quote:set(nil)
			FruitTradeService:Sell(currency):catch(warn)
			refocus()
		end

		local function openShop()
			quote:set(nil)
			description:set("")
			inShop:set(true)
			refocus()
			FruitTradeService:GetGoldenCompassPrice()
				:andThen(function(price: number)
					if not closed and type(price) == "number" then
						compassPrice:set(price)
					end
				end)
				:catch(warn)
		end

		-- Common and Uncommon fruits only sell for Beri: the other two only show for an
		-- offer that carries them.
		local currencyCells: { any } = {}
		for order, currency in CURRENCIES do
			local field: string, suffix: string, image: string, color: Color3 =
				currency[1], currency[2], currency[3], currency[4]
			table.insert(
				currencyCells,
				Kit.Stack(scope, {
					Name = field,
					LayoutOrder = order,
					Gap = Kit.Space.XS,
					Size = UDim2.fromOffset(CURRENCY_SIZE.X, CURRENCY_SIZE.Y + Kit.Space.XS + AMOUNT_HEIGHT),
					Visible = if field == "Beri"
						then nil
						else scope:Computed(function(use): boolean
							local offer = use(quote)
							return offer ~= nil and offer.Gems ~= nil
						end),
					Children = {
						Kit.Button(scope, {
							Name = "Sell",
							LayoutOrder = 1,
							Variant = "Ghost",
							Size = UDim2.fromOffset(CURRENCY_SIZE.X, CURRENCY_SIZE.Y),
							OnClick = function()
								sell(field)
							end,
							Children = {
								Kit.Image(scope, { Image = image, Size = UDim2.fromScale(1, 1) }),
							},
						}),
						Kit.Label(scope, {
							LayoutOrder = 2,
							Text = scope:Computed(function(use): string
								local offer: any = use(quote)
								local amount = offer and offer[field]
								return if amount then `{amount} {suffix}` else `.. {suffix}`
							end),
							Color = color,
							TextSize = Kit.TextSize.Heading,
							Fit = true,
							Size = UDim2.new(1, 0, 0, AMOUNT_HEIGHT),
						}),
					},
				})
			)
		end

		local contentTop = TITLE_HEIGHT + Kit.Space.S
		local contentHeight = -(contentTop + Kit.Space.S + ShopScreen.HINT_HEIGHT)
		local middleWidth = -2 * (SIDE_WIDTH + Kit.Space.XL)

		local main = ShopScreen.Board(scope, {
			Color = BOARD_COLOR,
			Transparency = 0.5,
			Padding = FRAME_MARGIN,
			Size = UDim2.fromOffset(MAIN_SIZE.X, MAIN_SIZE.Y),
			Visible = scope:Computed(function(use): boolean
				return not use(inShop)
			end),
			Children = {
				ShopScreen.Board(scope, {
					Name = "Frame",
					Color = BOARD_COLOR,
					Transparency = 0.5,
					Padding = Kit.Space.L,
					Size = UDim2.fromScale(1, 1),
					Children = {
						Kit.Label(scope, {
							Name = "shop",
							Text = "Suspicious Man From Quest Land",
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
									Text = GREETING,
									TextSize = Kit.TextSize.Heading,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),

						scope:New("Frame")({
							Name = "Selling",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(0.5, 0),
							Position = UDim2.new(0.5, 0, 0, contentTop),
							Size = UDim2.new(1, middleWidth, 1, contentHeight),
							[Fusion.Children] = {
								Kit.Panel(scope, {
									Name = "Offer",
									Image = "",
									Color = BOARD_COLOR,
									Transparency = 0,
									Padding = Kit.Space.M,
									-- Centred in what the button leaves of the column.
									AnchorPoint = Vector2.new(0, 0.5),
									Position = UDim2.new(0, 0, 0.5, -(BUTTON_SIZE.Y + Kit.Space.L) / 2),
									Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
									Visible = scope:Computed(function(use): boolean
										return use(quote) ~= nil
									end),
									Children = {
										-- Which fruit the offer is for; the old panels only carried the amounts.
										Kit.Label(scope, {
											Name = "Title",
											Text = scope:Computed(function(use): string
												local offer = use(quote)
												return if offer and type(offer.Fruit) == "string"
													then `Offer for {offer.Fruit}. Sell it for:`
													else "Sell it for:"
											end),
											TextSize = Kit.TextSize.Body,
											Fit = true,
											TextXAlignment = Enum.TextXAlignment.Left,
											Size = UDim2.new(1, -(CARD_HEADER + Kit.Space.S), 0, CARD_HEADER),
										}),
										Kit.Button(scope, {
											Name = "Close",
											Text = "X",
											Variant = "Red",
											AnchorPoint = Vector2.new(1, 0),
											Position = UDim2.fromScale(1, 0),
											Size = UDim2.fromOffset(CARD_HEADER, CARD_HEADER),
											OnClick = function()
												quote:set(nil)
												refocus()
											end,
										}),
										Kit.Stack(scope, {
											Name = "Currencies",
											Direction = "Horizontal",
											Gap = Kit.Space.L,
											HorizontalAlignment = Enum.HorizontalAlignment.Center,
											VerticalAlignment = Enum.VerticalAlignment.Center,
											Position = UDim2.fromOffset(0, CARD_HEADER),
											Size = UDim2.new(1, 0, 1, -CARD_HEADER),
											Children = currencyCells,
										}),
									},
								}),
								Kit.Button(scope, {
									Name = "Sell",
									Text = "Sell Fruit",
									-- Blue with a fruit in hand, grey without.
									Variant = scope:Computed(function(use): Kit.Variant
										return if use(holding) then "Blue" else "Grey"
									end),
									AnchorPoint = Vector2.new(0.5, 1),
									Position = UDim2.fromScale(0.5, 1),
									Size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y),
									OnClick = requestQuote,
								}),
							},
						}),

						scope:New("Frame")({
							Name = "Man",
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, contentTop),
							Size = UDim2.new(0, SIDE_WIDTH, 1, contentHeight),
							[Fusion.Children] = {
								Kit.Image(scope, {
									Name = "NPC",
									Image = NPC_IMAGE,
									AnchorPoint = Vector2.new(0.5, 0.5),
									Position = UDim2.new(0.5, 0, 0.5, -(BUTTON_SIZE.Y + Kit.Space.L) / 2),
									Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE),
								}),
								purpleButton(scope, {
									Name = "Shop",
									Text = "Shop",
									AnchorPoint = Vector2.new(0.5, 1),
									Position = UDim2.fromScale(0.5, 1),
									OnClick = openShop,
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

		-- An item of the shop page: its picture buys it, and describes it when hovered with
		-- the mouse or selected with the gamepad.
		local function item(
			order: number,
			name: string,
			image: string,
			price: Fusion.UsedAs<string>,
			buy: () -> (),
			text: () -> string
		): Instance
			return Kit.Stack(scope, {
				Name = name,
				LayoutOrder = order,
				Gap = Kit.Space.XS,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Size = UDim2.fromOffset(ITEMS_WIDTH, ITEM_SIZE + Kit.Space.XS + PRICE_HEIGHT),
				Children = {
					Kit.Button(scope, {
						Name = "Buy",
						LayoutOrder = 1,
						Variant = "Ghost",
						Size = UDim2.fromOffset(ITEM_SIZE, ITEM_SIZE),
						OnClick = buy,
						OnHover = function(hovering: boolean)
							if hovering then
								description:set(text())
							end
						end,
						Children = {
							Kit.Image(scope, { Image = image, Size = UDim2.fromScale(1, 1) }),
						},
					}),
					coins(scope, {
						Name = "Price",
						LayoutOrder = 2,
						Text = price,
						Size = UDim2.fromOffset(90, PRICE_HEIGHT),
					}),
				},
			})
		end

		local shopTop = COINS_SIZE.Y + Kit.Space.M
		local shopHeight = -(shopTop + Kit.Space.S + ShopScreen.HINT_HEIGHT)

		local shop = ShopScreen.Board(scope, {
			Name = "Shop",
			Color = BOARD_COLOR,
			Transparency = 0.5,
			Padding = FRAME_MARGIN,
			Size = UDim2.fromOffset(SHOP_SIZE.X, SHOP_SIZE.Y),
			Visible = inShop,
			Children = {
				ShopScreen.Board(scope, {
					Name = "Frame",
					Color = BOARD_COLOR,
					Transparency = 0.5,
					Padding = Kit.Space.L,
					Size = UDim2.fromScale(1, 1),
					Children = {
						Kit.Well(scope, {
							Name = "DFCoins",
							Color = Kit.Colors.Box,
							Transparency = 0.9,
							Padding = Kit.Space.XS,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							Size = UDim2.fromOffset(COINS_SIZE.X, COINS_SIZE.Y),
							Children = {
								coins(scope, {
									Text = scope:Computed(function(use): string
										return tostring(use(dfCoins))
									end),
									TextSize = Kit.TextSize.Heading,
									Size = UDim2.new(1, 0, 0, COINS_SIZE.Y - 2 * Kit.Space.XS),
								}),
							},
						}),

						Kit.Stack(scope, {
							Name = "Items",
							Gap = Kit.Space.L,
							Position = UDim2.fromOffset(0, shopTop),
							Size = UDim2.new(0, ITEMS_WIDTH, 1, shopHeight),
							Children = {
								item(
									1,
									"RemoveDF",
									REMOVE_IMAGE,
									tostring(SELLER.RemoveFruitCoins),
									function()
										FruitTradeService:RemoveFruit():catch(warn)
									end,
									function(): string
										return `Remove your first devil fruit. Costs {SELLER.RemoveFruitCoins} DFCoins`
									end
								),
								item(
									2,
									"GoldenCompass",
									COMPASS_IMAGE,
									scope:Computed(function(use): string
										return tostring(use(compassPrice))
									end),
									function()
										FruitTradeService:BuyGoldenCompass():catch(warn)
									end,
									function(): string
										return "A special compass made of pure gold. Has 80% chance of a Rare Box and 20% chance of a Ultra Rare Box. "
											.. `Costs {Fusion.peek(compassPrice)} DFCoins`
									end
								),
							},
						}),

						Kit.Well(scope, {
							Name = "Description",
							Color = Kit.Colors.Box,
							Transparency = 0.7,
							Padding = Kit.Space.L,
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.new(1, 0, 0, shopTop),
							Size = UDim2.new(
								1,
								-(ITEMS_WIDTH + Kit.Space.XL),
								1,
								shopHeight - (BUTTON_SIZE.Y + Kit.Space.M)
							),
							Children = {
								Kit.Label(scope, {
									Text = scope:Computed(function(use): string
										local text = use(description)
										return if text == "" then SHOP_GREETING else text
									end),
									TextSize = Kit.TextSize.Title,
									Fit = true,
									Size = UDim2.fromScale(1, 1),
								}),
							},
						}),
						purpleButton(scope, {
							Name = "Back",
							Text = "Back",
							AnchorPoint = Vector2.new(1, 1),
							Position = UDim2.new(1, 0, 1, -(Kit.Space.S + ShopScreen.HINT_HEIGHT)),
							OnClick = function()
								inShop:set(false)
								refocus()
							end,
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

		gui = Kit.Screen(scope, {
			Name = context.Name,
			Children = { main, shop },
		})
		return gui
	end,
}
