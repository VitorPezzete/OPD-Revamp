--!strict
--[[
	Menu tab "Shop": Robux products, gifting, the skin dye shops and the daily / hourly
	reward boxes.

	A product button sends the product's name (and the receiver of a gift) to
	MonetizationService, which decides what is prompted; nothing is prompted from the
	client. A reward box sends its kind and gets the amount back: it shakes until the
	server answers, then the lid lifts, the reward is shown and everything settles back.

	The badge of the tab button (boxes waiting) is drawn by the shell, which is always up.

	Auto menu: with the setting on, this tab closes as soon as the character moves.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local LocalCharacter = require(ReplicatedStorage.Client.Util.LocalCharacter)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local UI = require(ReplicatedStorage.Client.UI.Components)

local Kit = require(script.Parent.Kit)

type Scope = Theme.Scope
type UsedAs<T> = Theme.UsedAs<T>

local peek = Fusion.peek

local NO_FRUIT = "None"
local MAX_SHOWN = 99
-- Humanoid.Running reports tiny speeds while standing still.
local MOVING_SPEED = 0.5

local WINDOW_SIZE = Vector2.new(780, 640)
local PRODUCTS_WIDTH = 380
local BUTTON_HEIGHT = 38

-- Products of ProductConfig. All of these can be bought as a gift.
local GEM_PRODUCTS = {
	{ Product = "Gems100", Text = "100" },
	{ Product = "Gems1000", Text = "1,000" },
	{ Product = "Gems10000", Text = "10,000" },
}
local SLOT_PRODUCTS = {
	{ Product = "SlotD", Text = "Slot D" },
	{ Product = "SlotE", Text = "Slot E" },
	{ Product = "SlotF", Text = "Slot F" },
}
-- Screens opened from here (the tab closes).
local DYE_SCREENS = {
	{ Screen = "SkinDyeShop", Text = "Skin Dye Shop" },
	{ Screen = "SkinDyeShopAll", Text = "Rare Skin Dye Shop" },
}

-- Game art of the two boxes.
local DAILY_ART = { Box = "rbxassetid://2923887431", Lid = "rbxassetid://2923887976" }
local HOURLY_ART = { Box = "rbxassetid://2923887569", Lid = "rbxassetid://2923888043" }

-- { rotation, seconds } steps of one shake; the last step is followed by a pause.
local SHAKE = { { -20, 0.05 }, { 15, 0.1 }, { -10, 0.1 }, { 5, 0.1 } }
local SHAKE_SETTLE_SECONDS = 0.1
local SHAKE_PAUSE_SECONDS = 0.8
local OPEN_SECONDS = 0.5
local REWARD_SHOWN_SECONDS = 2
local IDLE_TRANSPARENCY = 0.7

type RewardBoxProps = {
	Title: string,
	Hint: string,
	Art: { Box: string, Lid: string },
	Color: Color3,
	LayoutOrder: number,
	Size: UDim2,
	-- Unopened boxes.
	Pending: Fusion.Value<any>,
	-- Asks the server to open one. Yields; returns the amount won or nil when refused.
	Claim: () -> number?,
	Format: (amount: number) -> string,
}

local function rewardBox(scope: Scope, props: RewardBoxProps): Instance
	local alive = true
	table.insert(scope, function()
		alive = false
	end)

	local busy = scope:Value(false)
	local rotation = scope:Value(0)
	local opened = scope:Value(false)
	local reward: Fusion.Value<string?> = scope:Value(nil :: string?)

	local pending = scope:Computed(function(use): number
		return tonumber(use(props.Pending)) or 0
	end)
	local imageTransparency = scope:Computed(function(use): number
		return if use(pending) > 0 or use(busy) then 0 else IDLE_TRANSPARENCY
	end)
	local shownRotation = scope:Spring(rotation, 60, 0.6)
	-- 0 closed, 1 open: the lid goes up and the box down.
	local openness = scope:Spring(
		scope:Computed(function(use): number
			return if use(opened) then 1 else 0
		end),
		Theme.Motion.SlowSpeed,
		Theme.Motion.Damping
	)

	local function open()
		local finished = false
		local amount: number? = nil
		task.spawn(function()
			local ok, result = pcall(props.Claim)
			amount = if ok and type(result) == "number" then result else nil
			finished = true
		end)

		-- Shakes until the server answers (or the tab is closed).
		repeat
			for _, step in SHAKE do
				if not alive then
					return
				end
				rotation:set(step[1])
				task.wait(step[2])
			end
			rotation:set(0)
			task.wait(SHAKE_SETTLE_SECONDS)
			if not finished then
				task.wait(SHAKE_PAUSE_SECONDS)
			end
		until finished or not alive

		if not amount or not alive then
			return
		end

		opened:set(true)
		task.wait(OPEN_SECONDS)
		if not alive then
			return
		end
		reward:set(props.Format(amount))
		task.wait(REWARD_SHOWN_SECONDS)
		if not alive then
			return
		end
		reward:set(nil)
		opened:set(false)
		task.wait(OPEN_SECONDS)
	end

	local function onOpen()
		if peek(busy) or peek(pending) < 1 then
			return
		end
		busy:set(true)
		task.spawn(function()
			open()
			if alive then
				rotation:set(0)
				busy:set(false)
			end
		end)
	end

	local function art(name: string, image: string, direction: number): Instance
		return UI.Image(scope, {
			Name = name,
			Image = image,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Transparency = imageTransparency,
			Rotation = shownRotation,
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromScale(0.5, 0.5 + direction * 0.2 * use(openness))
			end),
		})
	end

	return UI.Panel(scope, {
		Name = props.Title,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		Color = Theme.Colors.Raised,
		Padding = Theme.Space.M,
		Children = {
			UI.Label(scope, {
				Name = "Title",
				Text = props.Title,
				Variant = "BodyBold",
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 22),
			}),
			UI.Label(scope, {
				Name = "Hint",
				Text = props.Hint,
				Variant = "Small",
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, 0, 0, 18),
			}),
			UI.Badge(scope, {
				Name = "Alert",
				Color = Theme.Colors.Danger,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Visible = scope:Computed(function(use): boolean
					return use(pending) > 0
				end),
				Text = scope:Computed(function(use): string
					local count = use(pending)
					return if count > MAX_SHOWN then `{MAX_SHOWN}+` else tostring(count)
				end),
			}),
			scope:New("Frame")({
				Name = "Stage",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -Theme.Space.L),
				Size = UDim2.fromOffset(120, 120),
				[Fusion.Children] = {
					art("Box", props.Art.Box, 1),
					art("Lid", props.Art.Lid, -1),
				},
			}),
			UI.Label(scope, {
				Name = "Reward",
				Variant = "Title",
				Color = props.Color,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 0, 1, -(BUTTON_HEIGHT + Theme.Space.M)),
				Size = UDim2.new(1, -(120 + Theme.Space.M), 0, 40),
				Scaled = true,
				Text = scope:Computed(function(use): string
					return use(reward) or ""
				end),
			}),
			UI.Button(scope, {
				Name = "Open",
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
				Size = UDim2.new(1, -(120 + Theme.Space.M), 0, BUTTON_HEIGHT),
				Text = scope:Computed(function(use): string
					if use(busy) then
						return "Opening..."
					end
					return if use(pending) > 0 then "Open" else "Nothing yet"
				end),
				Disabled = scope:Computed(function(use): boolean
					return use(busy) or use(pending) < 1
				end),
				OnClick = onOpen,
			}),
		},
	})
end

return function(scope: Scope, context: any, menu: any): Instance
	local MonetizationService = Knit.GetService("MonetizationService")
	local DailyRewardService = Knit.GetService("DailyRewardService")
	local SettingsController = Knit.GetController("SettingsController")

	local localPlayer = Players.LocalPlayer

	----------------------------------------------------------------------------------
	-- Gifting: "Gift" opens the list of the other players; the one picked receives the
	-- next gems / slot purchase. Opening or closing the list clears the choice.

	local giftOpen = scope:Value(false)
	local receiver: Fusion.Value<Player?> = scope:Value(nil :: Player?)
	local others: Fusion.Value<{ Player }> = scope:Value({})

	local function refreshPlayers()
		local list = {}
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer then
				table.insert(list, player)
			end
		end
		others:set(list)

		local chosen = peek(receiver)
		if chosen and not table.find(list, chosen) then
			receiver:set(nil)
		end
	end
	Bind.connect(scope, Players.PlayerAdded, refreshPlayers)
	Bind.connect(scope, Players.PlayerRemoving, function()
		-- The leaving player is still listed while this event runs.
		task.defer(refreshPlayers)
	end)

	local function prompt(productName: string)
		local chosen = peek(receiver)
		Kit.send(MonetizationService:Prompt(productName, if chosen then chosen.UserId else nil))
	end

	local function productRow(products: { { Product: string, Text: string } }, order: number): Instance
		local buttons: { Instance } = {}
		for index, product in products do
			table.insert(
				buttons,
				UI.Button(scope, {
					Name = product.Product,
					Text = product.Text,
					TextSize = Theme.TextSize.Small,
					LayoutOrder = index,
					Size = UDim2.new(1 / #products, -Theme.Space.S, 1, 0),
					OnClick = function()
						prompt(product.Product)
					end,
				})
			)
		end
		return UI.Stack(scope, {
			Direction = "Horizontal",
			Gap = Theme.Space.S,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			Children = buttons,
		})
	end

	local function caption(text: UsedAs<string>, order: number): Instance
		return UI.Label(scope, {
			Text = text,
			Variant = "Small",
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 18),
		})
	end

	local fruit = Bind.data(scope, "DevilFruits.Slot1.Name", NO_FRUIT)
	local hasFruit = scope:Computed(function(use): boolean
		return use(fruit) ~= NO_FRUIT
	end)

	local productItems: { any } = {
		caption("Gems", 1),
		productRow(GEM_PRODUCTS, 2),
		caption("Customize slots", 3),
		productRow(SLOT_PRODUCTS, 4),
	}
	for index, entry in DYE_SCREENS do
		table.insert(
			productItems,
			UI.Button(scope, {
				Name = entry.Screen,
				Text = entry.Text,
				Variant = "Secondary",
				TextSize = Theme.TextSize.Small,
				LayoutOrder = 4 + index,
				Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
				OnClick = function()
					menu.Close()
					context.Open(entry.Screen)
				end,
			})
		)
	end
	table.insert(
		productItems,
		UI.Button(scope, {
			Name = "RemoveFruit",
			Variant = "Danger",
			TextSize = Theme.TextSize.Small,
			LayoutOrder = 10,
			Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			Text = scope:Computed(function(use): string
				local name = use(fruit)
				return if name ~= NO_FRUIT then `Remove {name} Fruit` else "Remove Devil Fruit"
			end),
			Disabled = scope:Computed(function(use): boolean
				return not use(hasFruit)
			end),
			OnClick = function()
				if peek(fruit) ~= NO_FRUIT then
					Kit.send(MonetizationService:Prompt("RemoveFruit"))
				end
			end,
		})
	)
	table.insert(
		productItems,
		UI.Button(scope, {
			Name = "Gift",
			Variant = "Secondary",
			TextSize = Theme.TextSize.Small,
			LayoutOrder = 11,
			Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			Selected = giftOpen,
			Text = scope:Computed(function(use): string
				local chosen = use(receiver)
				return if chosen then `Gift to {chosen.Name}` else "Gift"
			end),
			OnClick = function()
				receiver:set(nil)
				refreshPlayers()
				giftOpen:set(not peek(giftOpen))
			end,
		})
	)
	table.insert(
		productItems,
		UI.Scroll(scope, {
			Name = "GiftPlayers",
			LayoutOrder = 12,
			Size = UDim2.new(1, 0, 0, 132),
			Gap = Theme.Space.XS,
			Visible = giftOpen,
			Children = {
				caption(
					scope:Computed(function(use): string
						return if #use(others) > 0
							then "The next gems or slot purchase goes to:"
							else "Nobody else is on this server."
					end),
					0
				),
				scope:ForValues(others, function(_use, rowScope: Scope, player: Player)
					return UI.Button(rowScope, {
						Name = player.Name,
						Text = player.Name,
						Variant = "Secondary",
						TextSize = Theme.TextSize.Small,
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 32),
						Selected = rowScope:Computed(function(use): boolean
							return use(receiver) == player
						end),
						OnClick = function()
							receiver:set(player)
						end,
					})
				end),
			},
		})
	)

	----------------------------------------------------------------------------------
	-- Reward boxes: the daily one gives gems, the hourly one Beri.

	local daily = Bind.data(scope, "Rewards.Daily.N", 0)
	local hourly = Bind.data(scope, "Rewards.Hourly.N", 0)

	local function claim(kind: string): () -> number?
		return function(): number?
			local ok, amount = DailyRewardService:Claim(kind):await()
			return if ok and type(amount) == "number" then amount else nil
		end
	end

	local boxSize = UDim2.new(1, 0, 0.5, -Theme.Space.S / 2)

	----------------------------------------------------------------------------------
	-- Auto menu

	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not alive or not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		Bind.connect(scope, humanoid.Running, function(speed: number)
			if speed > MOVING_SPEED and SettingsController:Get("Auto_Menu") == true then
				menu.Close()
			end
		end)
	end
	local character = LocalCharacter.Get()
	if character then
		task.spawn(watchCharacter, character)
	end

	----------------------------------------------------------------------------------

	return UI.Window(scope, {
		Name = "Shop",
		Title = "Shop",
		Size = UDim2.fromOffset(WINDOW_SIZE.X, WINDOW_SIZE.Y),
		AnchorPoint = Kit.WindowAnchor,
		Position = Kit.WindowPosition,
		OnClose = menu.Close,
		Children = {
			Kit.Section(scope, {
				Name = "Products",
				Title = "Products",
				Size = UDim2.new(0, PRODUCTS_WIDTH, 1, 0),
				Children = UI.Stack(scope, {
					Gap = Theme.Space.S,
					Size = UDim2.fromScale(1, 1),
					Children = productItems,
				}),
			}),
			Kit.Section(scope, {
				Name = "Rewards",
				Title = "Rewards",
				Position = UDim2.fromOffset(PRODUCTS_WIDTH + Theme.Space.M, 0),
				Size = UDim2.new(1, -(PRODUCTS_WIDTH + Theme.Space.M), 1, 0),
				Children = UI.Stack(scope, {
					Gap = Theme.Space.S,
					Size = UDim2.fromScale(1, 1),
					Children = {
						rewardBox(scope, {
							Title = "Daily box",
							Hint = "Gives gems",
							Art = DAILY_ART,
							Color = Theme.Colors.Gems,
							LayoutOrder = 1,
							Size = boxSize,
							Pending = daily,
							Claim = claim("Daily"),
							Format = function(amount: number): string
								return `+{Bind.formatNumber(amount)} gems`
							end,
						}),
						rewardBox(scope, {
							Title = "Hourly box",
							Hint = "Gives Beri",
							Art = HOURLY_ART,
							Color = Theme.Colors.Beri,
							LayoutOrder = 2,
							Size = boxSize,
							Pending = hourly,
							Claim = claim("Hourly"),
							Format = function(amount: number): string
								return `+${Bind.formatNumber(amount)}`
							end,
						}),
					},
				}),
			}),
		},
	})
end
