--!strict
--[[
	Menu tab "Shop": the daily / hourly reward boxes, the Robux products and gifting.

	One parchment sheet in the middle of the screen (menu.Centre), everything on one grid:

		Shop
		[ daily box ]   [ hourly box ]                         the reward boxes
		Devil Fruit    Gems    Customize Slots    Buy For      three columns of blue
		 ...            ...     ...                 Myself      buttons and the list of
		                                            <players>   who the purchase is for

	The old menu drew two separate sheets (boxes above, buttons below, a Gift button that
	opened a list of players); the buttons, their columns and their order are the same.

		Shop(scope, context, menu): GuiObject     -- the panel, for the shell to show

	A product button sends the product's name (and the receiver of a gift) to
	MonetizationService, which decides what is prompted; nothing is prompted from the
	client. "Buy For" replaces the Gift button: "Myself" is picked until another player
	is, and whoever is picked receives the next gems / slot purchase. The reward boxes
	send the kind of box and get the amount back; each keeps its own counter (the one on
	the menu button is the shell's).

	Not rebuilt: "Buy Skip Affinity", hidden in the old menu and without code.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local Closers = require(ReplicatedStorage.Client.UI.Util.Closers)
local Kit = require(ReplicatedStorage.Client.UI.Legacy.Kit)
local PlaceManifest = require(ReplicatedStorage.Shared.Configs.PlaceManifest)
local RewardBox = require(ReplicatedStorage.Client.UI.Legacy.Components.RewardBox)

type Scope = Fusion.Scope<typeof(Fusion)>

-- Key of this tab (PlaceManifest.MenuTabs), which is what menu.Selected holds.
local TAB_KEY = "Shop"
local SERVICES = { "MonetizationService", "DailyRewardService" }
local NO_FRUIT = "None"
-- Humanoid.Running reports tiny speeds while standing still.
local MOVING_SPEED = 0.5

-- The picture the old menu laid behind its sheets.
local SHEET_IMAGE = "rbxassetid://1012758197"
local GEM_ICON = "rbxassetid://1954296071"

-- Design pixels. Every row of the sheet is INNER_WIDTH wide.
local SHEET_PADDING = Kit.Space.XL
local TITLE_HEIGHT = 44
local HEADING_HEIGHT = 28
local BUTTON_SIZE = Vector2.new(224, 56)
local COLUMN_GAP = Kit.Space.M
local ROW_GAP = Kit.Space.S
local RECEIVER_WIDTH = 252
local PLAYER_ROW_HEIGHT = 40
-- Legacy.Components.RewardBox draws a cell of this size.
local REWARD_CELL = Vector2.new(300, 250)
local CAPTION_HEIGHT = 32

type Entry = { Text: string, Product: string?, Screen: string? }
type Column = { Heading: string, Entries: { Entry } }

-- The columns of buttons, left to right, as the old sheet had them. A product is a name
-- of ProductConfig (all of them can be bought as a gift); a screen closes the tab.
local REMOVE_FRUIT = "RemoveFruit"
local COLUMNS: { Column } = {
	{
		Heading = "Devil Fruit & Skin",
		Entries = {
			{ Text = "", Product = REMOVE_FRUIT },
			{ Text = "Skin Dye Shop", Screen = "SkinDyeShop" },
			{ Text = "Rare Skin Dye Shop", Screen = "SkinDyeShopAll" },
		},
	},
	{
		Heading = "Gems",
		Entries = {
			{ Text = "100 Gems", Product = "Gems100" },
			{ Text = "1000 Gems", Product = "Gems1000" },
			{ Text = "10000 Gems", Product = "Gems10000" },
		},
	},
	{
		Heading = "Customize Slots",
		Entries = {
			{ Text = "Slot D", Product = "SlotD" },
			{ Text = "Slot E", Product = "SlotE" },
			{ Text = "Slot F", Product = "SlotF" },
		},
	},
}
local ROWS = 3

local COLUMN_HEIGHT = HEADING_HEIGHT + ROWS * BUTTON_SIZE.Y + (ROWS - 1) * ROW_GAP
local INNER_WIDTH = #COLUMNS * (BUTTON_SIZE.X + COLUMN_GAP) + RECEIVER_WIDTH
local SHEET_SIZE = Vector2.new(
	INNER_WIDTH + 2 * SHEET_PADDING,
	2 * SHEET_PADDING + TITLE_HEIGHT + REWARD_CELL.Y + COLUMN_HEIGHT + 2 * Kit.Space.M
)

local MYSELF_TEXT = "Myself"

return function(scope: Scope, context: any, menu: any): GuiObject?
	-- No panel in a place that does not load what the buttons call.
	for _, service in SERVICES do
		if not PlaceManifest.Has("Services", service) then
			return nil
		end
	end

	local MonetizationService = Knit.GetService("MonetizationService")
	local DailyRewardService = Knit.GetService("DailyRewardService")
	local SettingsController = Knit.GetController("SettingsController")

	local localPlayer = Players.LocalPlayer

	local alive = true
	table.insert(scope, function()
		alive = false
	end)

	----------------------------------------------------------------------------------
	-- Who the next gems / slot purchase is for: the player (nil) or another one.

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

		local chosen = Fusion.peek(receiver)
		if chosen and not table.find(list, chosen) then
			receiver:set(nil)
		end
	end
	Bind.connect(scope, Players.PlayerAdded, refreshPlayers)
	Bind.connect(scope, Players.PlayerRemoving, function()
		-- The leaving player is still listed while this event runs.
		task.defer(refreshPlayers)
	end)
	refreshPlayers()

	local function receiverRow(rowScope: any, text: string, player: Player?, order: number): Instance
		return Kit.Button(rowScope, {
			Name = if player then player.Name else MYSELF_TEXT,
			Text = text,
			Variant = "Grey",
			TextSize = Kit.TextSize.Small,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, PLAYER_ROW_HEIGHT),
			Selected = rowScope:Computed(function(use): boolean
				return use(receiver) == player
			end),
			OnClick = function()
				receiver:set(player)
			end,
		})
	end

	-- The name of a column, in the first HEADING_HEIGHT pixels of it (gap included).
	local function heading(text: string): Instance
		return Kit.Label(scope, {
			Name = "Heading",
			Text = text,
			TextSize = Kit.TextSize.Body,
			Fit = true,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, HEADING_HEIGHT - ROW_GAP),
		})
	end

	local receivers = Kit.Stack(scope, {
		Name = "BuyFor",
		LayoutOrder = #COLUMNS + 1,
		Gap = ROW_GAP,
		Size = UDim2.fromOffset(RECEIVER_WIDTH, COLUMN_HEIGHT),
		Children = {
			heading("Buy For"),
			Kit.Scroll(scope, {
				Name = "GiftPlayers",
				LayoutOrder = 1,
				Gap = Kit.Space.XS,
				Padding = Kit.Space.XS,
				Size = UDim2.new(1, 0, 1, -HEADING_HEIGHT),
				Children = {
					receiverRow(scope, MYSELF_TEXT, nil, 0),
					scope:ForValues(others, function(_use, rowScope: any, player: Player)
						return receiverRow(rowScope, player.Name, player, 1)
					end),
				} :: { any },
			}),
		},
	})

	----------------------------------------------------------------------------------
	-- Products

	local fruit = Bind.data(scope, "DevilFruits.Slot1.Name", NO_FRUIT)

	local function productButton(entry: Entry, order: number): Instance
		local size = UDim2.fromOffset(BUTTON_SIZE.X, BUTTON_SIZE.Y)
		if entry.Screen then
			local screenName = entry.Screen
			return Kit.Button(scope, {
				Name = screenName,
				Text = entry.Text,
				Variant = "Blue",
				Size = size,
				LayoutOrder = order,
				OnClick = function()
					menu.Close()
					context.Open(screenName)
				end,
			})
		elseif entry.Product == REMOVE_FRUIT then
			-- Grey while there is no fruit to remove, as the old button was.
			return Kit.Button(scope, {
				Name = "RemoveDFShop",
				Size = size,
				LayoutOrder = order,
				Variant = scope:Computed(function(use): Kit.Variant
					return if use(fruit) ~= NO_FRUIT then "Blue" else "Grey"
				end),
				Text = scope:Computed(function(use): string
					local name = use(fruit)
					return if name ~= NO_FRUIT then `Remove {name} Fruit` else "Remove Devil Fruit"
				end),
				OnClick = function()
					if Fusion.peek(fruit) ~= NO_FRUIT then
						MonetizationService:Prompt(REMOVE_FRUIT):catch(warn)
					end
				end,
			})
		end
		local productName = entry.Product :: string
		return Kit.Button(scope, {
			Name = productName,
			Text = entry.Text,
			Variant = "Blue",
			Size = size,
			LayoutOrder = order,
			OnClick = function()
				local chosen = Fusion.peek(receiver)
				MonetizationService:Prompt(productName, if chosen then chosen.UserId else nil):catch(warn)
			end,
		})
	end

	local columns: { Instance } = {}
	for columnOrder, column in COLUMNS do
		local buttons: { Instance } = { heading(column.Heading) }
		for order, entry in column.Entries do
			table.insert(buttons, productButton(entry, order))
		end
		table.insert(
			columns,
			Kit.Stack(scope, {
				Name = `Column{columnOrder}`,
				LayoutOrder = columnOrder,
				Gap = ROW_GAP,
				Size = UDim2.fromOffset(BUTTON_SIZE.X, COLUMN_HEIGHT),
				Children = buttons,
			})
		)
	end
	table.insert(columns, receivers)

	local products = Kit.Stack(scope, {
		Name = "Products",
		Direction = "Horizontal",
		Gap = COLUMN_GAP,
		LayoutOrder = 3,
		Size = UDim2.fromOffset(INNER_WIDTH, COLUMN_HEIGHT),
		Children = columns,
	})

	----------------------------------------------------------------------------------
	-- Reward boxes: the daily one pays gems, the hourly one Beri.

	local daily = Bind.data(scope, "Rewards.Daily.N", 0)
	local hourly = Bind.data(scope, "Rewards.Hourly.N", 0)

	local function claim(kind: string): () -> number?
		return function(): number?
			local ok, amount = DailyRewardService:Claim(kind):await()
			return if ok and type(amount) == "number" then amount else nil
		end
	end

	-- A box in its cell, its name written along the foot of the cell.
	local function reward(order: number, caption: string, box: Instance): Instance
		return scope:New("Frame")({
			Name = caption,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.fromOffset(REWARD_CELL.X, REWARD_CELL.Y),
			[Fusion.Children] = {
				box,
				Kit.Label(scope, {
					Name = "Caption",
					Text = caption,
					TextSize = Kit.TextSize.Body,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, -Kit.Space.S),
					Size = UDim2.new(1, 0, 0, CAPTION_HEIGHT),
				}),
			},
		})
	end

	local rewards = Kit.Well(scope, {
		Name = "Rewards",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(INNER_WIDTH, REWARD_CELL.Y),
		Children = Kit.Stack(scope, {
			Direction = "Horizontal",
			Gap = Kit.Space.XL * 2,
			Size = UDim2.fromScale(1, 1),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Children = {
				reward(1, "Daily Reward", RewardBox(scope, {
					Name = "Daily",
					BoxImage = "rbxassetid://2923887431",
					LidImage = "rbxassetid://2923887976",
					BurstColor = Color3.fromRGB(189, 255, 255),
					RewardColor = Color3.fromRGB(0, 255, 255),
					Icon = GEM_ICON,
					Pending = daily,
					Claim = claim("Daily"),
					Format = function(amount: number): string
						return Bind.formatNumber(amount)
					end,
				})),
				reward(2, "Hourly Reward", RewardBox(scope, {
					Name = "Hourly",
					BoxImage = "rbxassetid://2923887569",
					LidImage = "rbxassetid://2923888043",
					BurstColor = Color3.fromRGB(255, 189, 189),
					RewardColor = Color3.fromRGB(0, 255, 0),
					Pending = hourly,
					Claim = claim("Hourly"),
					Format = function(amount: number): string
						return "$" .. Bind.formatNumber(amount)
					end,
				})),
			},
		}),
	})

	----------------------------------------------------------------------------------
	-- Auto menu: with the setting on, this tab closes as soon as the character moves.

	local function watchCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		-- The menu may be gone by the time the character is ready (interface swapped).
		if not alive or not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		Bind.connect(scope, humanoid.Running, function(speed: number)
			if
				speed > MOVING_SPEED
				and Fusion.peek(menu.Selected) == TAB_KEY
				and SettingsController:Get("Auto_Menu") == true
			then
				menu.Close()
			end
		end)
	end
	Bind.connect(scope, localPlayer.CharacterAdded, function(character: Model)
		task.spawn(watchCharacter, character)
	end)
	if localPlayer.Character then
		task.spawn(watchCharacter, localPlayer.Character)
	end

	local panel = Kit.Panel(scope, {
		Name = "Shop",
		Image = SHEET_IMAGE,
		Size = UDim2.fromOffset(SHEET_SIZE.X, SHEET_SIZE.Y),
		Children = Kit.Stack(scope, {
			Size = UDim2.fromScale(1, 1),
			Padding = SHEET_PADDING,
			Gap = Kit.Space.M,
			Children = {
				Kit.Label(scope, {
					Name = "Title",
					Text = "Shop",
					TextSize = Kit.TextSize.Title,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(INNER_WIDTH, TITLE_HEIGHT),
				}),
				rewards,
				products,
			},
		}),
	})
	-- In the middle of the screen.
	menu.Centre(panel, SHEET_SIZE)
	-- The gamepad's B closes the tab from anywhere inside it, as it closes a window.
	Closers.register(scope, panel, menu.Close)
	return panel
end
