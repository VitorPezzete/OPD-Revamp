--!strict
--[[
	Builds the screen module of an item merchant: a window listing the merchant's
	catalogue (ShopConfig.Merchants) as rows of icon, name, price and a Buy button.

		return ShopWindow.new({
			Name = "Shop2",                      -- name of the ScreenGui
			Title = "Sword Shop",
			Merchants = { "SwordMerchant" },
			Icons = { Dagger = "rbxassetid://..." },         -- optional game art per item
			Speaker = "Timmy", Dialogue = "Hi, I'm Timmy!",   -- optional line of the merchant
		})

	Names and prices are printed from ShopConfig. A click only sends the merchant and item
	names; ShopService decides everything. A purchase that goes through closes the shop,
	and so does walking away (there is no close button, as in every merchant window).

	Variants: by default the whole catalogue is listed. A shop whose list depends on what
	the player owns (the boat shops only show the Galleon to owners of a Sturdy Rod) lists
	its variants; the first one whose conditions hold is shown.

	The helpers (closeOnMove, getMerchantName, buy, priceText) are also used by the
	merchant screens that are not plain catalogues.
	Not part of Components/init: require it by its path.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local Bind = require(ReplicatedStorage.Client.UI.Util.Bind)
local MerchantDialogue = require(ReplicatedStorage.Client.UI.Util.MerchantDialogue)
local Theme = require(ReplicatedStorage.Client.UI.Theme)

local Button = require(script.Parent.Button)
local Image = require(script.Parent.Image)
local Label = require(script.Parent.Label)
local Panel = require(script.Parent.Panel)
local Screen = require(script.Parent.Screen)
local Scroll = require(script.Parent.Scroll)
local Window = require(script.Parent.Window)
local MerchantSpeech = require(script.Parent.MerchantSpeech)

type Scope = Theme.Scope

export type Variant = {
	-- Item names in display order; nil = the whole catalogue of the merchant.
	Items: { string }?,
	-- Shown only while the player owns / does not own this item (data.Items).
	RequiresItem: string?,
	HiddenWithItem: string?,
}

export type Options = {
	Name: string,
	Title: string,
	Merchants: { string },
	Icons: { [string]: string }?,
	Speaker: string?,
	Dialogue: string?,
	Variants: { Variant }?,
}

type Entry = { Order: number, Item: ShopConfig.Item }

local WINDOW_WIDTH = 580
local HEADER_HEIGHT = 52
local ROW_HEIGHT = 72
local ROW_GAP = Theme.Space.S
local ICON_SIZE = 52
local BUY_WIDTH = 110
local PRICE_WIDTH = 130
local SPEECH_HEIGHT = 120
local HINT_HEIGHT = 22
local MAX_VISIBLE_ROWS = 6
local DEFAULT_VARIANTS: { Variant } = { {} }

local ShopWindow = {}

ShopWindow.HINT = "Walk away to close"

-- Merchant windows have no close button: walking away (or dying) closes them.
function ShopWindow.closeOnMove(scope: Scope, context: any)
	MerchantDialogue.closeOnMove(scope :: any, function()
		context.Close()
	end)
end

-- The merchant model that opened the screen, or the screen's first merchant.
function ShopWindow.getMerchantName(context: any, merchants: { string }): string
	local args = context.Args
	local merchant = if type(args) == "table" then args.Merchant else nil
	if typeof(merchant) == "Instance" and ShopConfig.Merchants[merchant.Name] then
		return merchant.Name
	end
	return merchants[1]
end

-- Sends the purchase; `onDone(success)` runs when the server has answered.
function ShopWindow.buy(merchantName: string, itemName: string, onDone: ((success: boolean) -> ())?)
	Knit.GetService("ShopService")
		:Buy(merchantName, itemName)
		:andThen(function(success: boolean)
			if onDone then
				onDone(success == true)
			end
		end)
		:catch(function(problem: any)
			warn(`[Shop] purchase failed: {problem}`)
			if onDone then
				onDone(false)
			end
		end)
end

-- "$ 1,000" / "100 Gems", and the colour of that currency.
function ShopWindow.priceText(price: number, currency: string?): (string, Color3)
	if currency == "Gems" then
		return `{Bind.formatNumber(price)} Gems`, Theme.Colors.Gems
	end
	return `$ {Bind.formatNumber(price)}`, Theme.Colors.Beri
end

local function requirementText(item: ShopConfig.Item): string?
	if item.Requirement then
		return `Requires {item.Requirement.Skill} level {item.Requirement.Level}`
	elseif item.RequiresItem then
		return `Requires {item.RequiresItem}`
	end
	return nil
end

local function variantShown(variant: Variant, owned: { [string]: any }): boolean
	if variant.RequiresItem and owned[variant.RequiresItem] ~= true then
		return false
	end
	if variant.HiddenWithItem and owned[variant.HiddenWithItem] == true then
		return false
	end
	return true
end

local function row(scope: Scope, entry: Entry, icon: string?, hasIcons: boolean, disabled: any, onBuy: () -> ()): Frame
	local item = entry.Item
	local price, priceColor = ShopWindow.priceText(item.Price, item.Currency)
	local requirement = requirementText(item)
	local left = if hasIcons then ICON_SIZE + Theme.Space.M else 0
	local right = BUY_WIDTH + Theme.Space.M + PRICE_WIDTH + Theme.Space.M

	return Panel(scope, {
		Name = item.Name,
		LayoutOrder = entry.Order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Color = Theme.Colors.Raised,
		Padding = Theme.Space.S + 2,
		Children = {
			if hasIcons
				then Image(scope, {
					Name = "Icon",
					Image = icon or "",
					Background = Theme.Colors.Sunken,
					Radius = Theme.Radius.Small,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
				})
				else nil,
			Label(scope, {
				Name = "Title",
				Text = item.Name,
				Variant = "BodyBold",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, left, 0.5, if requirement then -10 else 0),
				Size = UDim2.new(1, -(left + right), 0, 24),
			}),
			if requirement
				then Label(scope, {
					Name = "Requirement",
					Text = requirement,
					Variant = "Tiny",
					Color = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, left, 0.5, 12),
					Size = UDim2.new(1, -(left + right), 0, 18),
				})
				else nil,
			Label(scope, {
				Name = "Price",
				Text = price,
				Variant = "BodyBold",
				Color = priceColor,
				TextXAlignment = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(BUY_WIDTH + Theme.Space.M), 0.5, 0),
				Size = UDim2.fromOffset(PRICE_WIDTH, 24),
			}),
			Button(scope, {
				Name = "Buy",
				Text = "Buy",
				Disabled = disabled,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(BUY_WIDTH, 42),
				OnClick = onBuy,
			}),
		} :: { any },
	})
end

function ShopWindow.new(options: Options)
	local variants = options.Variants or DEFAULT_VARIANTS

	return {
		Merchants = options.Merchants,

		Mount = function(scope: Scope, _gui: any, context: any)
			local merchantName = ShopWindow.getMerchantName(context, options.Merchants)
			local catalogue = ShopConfig.Merchants[merchantName]
			local icons = options.Icons or {}
			local hasIcons = next(icons) ~= nil

			local ownedItems = Bind.data(scope :: any, "Items", {})
			local beri = Bind.data(scope :: any, "Economy.Beri", 0)
			local busy = scope:Value(false)
			local closed = false
			table.insert(scope, function()
				closed = true
			end)

			-- One entry per catalogue item, built once: the list only filters them.
			local entries: { [string]: Entry } = {}
			local all: { Entry } = {}
			for index, item in if catalogue then catalogue.Items else {} do
				local entry = { Order = index, Item = item }
				entries[item.Name] = entry
				table.insert(all, entry)
			end

			local mostRows = 0
			for _, variant in variants do
				mostRows = math.max(mostRows, if variant.Items then #variant.Items else #all)
			end
			mostRows = math.clamp(mostRows, 1, MAX_VISIBLE_ROWS)

			local shown = scope:Computed(function(use): { Entry }
				local owned = use(ownedItems)
				if type(owned) ~= "table" then
					owned = {}
				end
				for _, variant in variants do
					if variantShown(variant, owned) then
						if not variant.Items then
							return all
						end
						local list = {}
						for _, name in variant.Items do
							if entries[name] then
								table.insert(list, entries[name])
							end
						end
						return list
					end
				end
				return {}
			end)

			-- The server refuses a disabled catalogue anyway; the buttons only say so.
			local disabled = scope:Computed(function(use): boolean
				return use(busy) or (catalogue ~= nil and catalogue.Disabled == true)
			end)

			local function buy(itemName: string)
				if Fusion.peek(busy) then
					return
				end
				busy:set(true)
				ShopWindow.buy(merchantName, itemName, function(success: boolean)
					if closed then
						return
					end
					busy:set(false)
					if success then
						context.Close()
					end
				end)
			end

			local hasSpeech = options.Dialogue ~= nil
			local speechSpace = if hasSpeech then SPEECH_HEIGHT + Theme.Space.M else 0
			local listHeight = mostRows * ROW_HEIGHT + (mostRows - 1) * ROW_GAP + Theme.Space.S * 2
			local bodyHeight = speechSpace + listHeight + Theme.Space.S + HINT_HEIGHT

			ShopWindow.closeOnMove(scope, context)

			return Screen(scope, {
				Name = options.Name,
				Children = Window(scope, {
					Title = options.Title,
					Subtitle = scope:Computed(function(use): string
						return `$ {Bind.formatNumber(tonumber(use(beri)) or 0)}`
					end),
					Size = UDim2.fromOffset(WINDOW_WIDTH, HEADER_HEIGHT + Theme.Space.L * 2 + bodyHeight),
					Children = {
						if hasSpeech
							then MerchantSpeech(scope, {
								Speaker = options.Speaker,
								Text = options.Dialogue :: string,
								Height = SPEECH_HEIGHT,
							})
							else nil,
						Scroll(scope, {
							Name = "Items",
							Position = UDim2.fromOffset(0, speechSpace),
							Size = UDim2.new(1, 0, 0, listHeight),
							Gap = ROW_GAP,
							Children = scope:ForValues(shown, function(_, rowScope: any, entry: Entry)
								return row(rowScope, entry, icons[entry.Item.Name], hasIcons, disabled, function()
									buy(entry.Item.Name)
								end)
							end),
						}),
						Label(scope, {
							Name = "Hint",
							Text = if catalogue and catalogue.Disabled
								then "Nothing is for sale right now. " .. ShopWindow.HINT
								else ShopWindow.HINT,
							Variant = "Tiny",
							AnchorPoint = Vector2.new(0.5, 1),
							Position = UDim2.fromScale(0.5, 1),
							Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
						}),
					} :: { any },
				}),
			})
		end,
	}
end

return ShopWindow
