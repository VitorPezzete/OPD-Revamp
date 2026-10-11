--!strict
--[[
	SellerMerchant: buys fruit items and sells two things for DF coins.

	Selling always concerns the fruit the character is holding; the client only picks
	the currency. The price comes from the fruit's rarity. A fruit can be sold by the
	player it was first given to, or by anyone when it has an aura (legacy rule).

	Fixed from the legacy remote:
	- It destroyed the fruit after the currency branch whatever happened inside it, so
	  asking gems or DF coins for a Common fruit deleted it for nothing.
	- "RemoveDF" charged 2 DF coins without checking there was a fruit to remove.
	- Nothing checked the player was at the merchant, alive, or had loaded data.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local SELLER = FruitEconomyConfig.Seller
-- The merchant's ClickDetector reaches 32 studs.
local MERCHANT_RANGE = 35
local ITEM_FOLDER = "Items"

local CURRENCY_PATHS: { [string]: string } = {
	Beri = "Economy.Beri",
	Gems = "Economy.Gems",
	DFCoins = "Economy.DFCoins",
}

export type Quote = { Fruit: string, Beri: number, Gems: number?, DFCoins: number? }

local FruitTradeService = Knit.CreateService({
	Name = "FruitTradeService",
	Client = {},
})

-- (player, fruitName, currency, hasAura) after a fruit was sold.
FruitTradeService.Sold = Signal.new() :: Signal.Signal<Player, string, string, boolean>
-- (player) after a Golden Compass was bought with DF coins.
FruitTradeService.GoldenCompassBought = Signal.new() :: Signal.Signal<Player>

local DataService
local CharacterService
local FruitService
local FruitLogService
local NotifyService
local WorldEventService

local requestLimiter = RateLimiter.new(4, 2)

-- The data and living character of a player standing at the merchant.
local function getCustomer(player: Player): (any, any)
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not requestLimiter:Consume(player) then
		return nil, nil
	end
	if not Proximity.GetMerchant(player, SELLER.Merchant, MERCHANT_RANGE) then
		return nil, nil
	end
	return data, entity
end

-- The held fruit, if this player may sell it.
local function getSellable(player: Player, entity: any): (Tool?, any, FruitEconomyConfig.SellPrices?)
	local tool = entity.Model:FindFirstChildOfClass("Tool")
	local item = tool and FruitService:GetItem(tool)
	if not tool or not item then
		return nil, nil, nil
	end
	if not item.HasAura and FruitLogService:GetOwnerId(tool, player) ~= player.UserId then
		return nil, nil, nil
	end
	return tool, item, FruitEconomyConfig.GetSellPrices(item.FruitName)
end

-- What the merchant offers for the held fruit; nil when there is nothing to sell.
function FruitTradeService.Client:GetQuote(player: Player): Quote?
	local data, entity = getCustomer(player)
	if not data then
		return nil
	end

	local _, item, prices = getSellable(player, entity)
	if not item or not prices then
		return nil
	end
	return { Fruit = item.FruitName, Beri = prices.Beri, Gems = prices.Gems, DFCoins = prices.DFCoins }
end

function FruitTradeService.Client:Sell(player: Player, currency: unknown): boolean
	local path = if type(currency) == "string" then CURRENCY_PATHS[currency] else nil
	if not path then
		return false
	end

	local data, entity = getCustomer(player)
	if not data or not data:IsActive() then
		return false
	end

	local tool, item, prices = getSellable(player, entity)
	local amount = prices and (prices :: any)[currency]
	if not tool or not item or type(amount) ~= "number" then
		return false
	end

	FruitLogService:RecordTool(player, `Sold {currency}`, tool)
	-- The fruit is gone before anything is paid.
	tool:Destroy()
	data:Increment(path, amount)
	if item.HasAura then
		data:Increment("Quests.AuraSold", 1)
	end

	FruitTradeService.Sold:Fire(player, item.FruitName, currency :: string, item.HasAura)
	return true
end

-- Removes the first devil fruit; the second one, if any, takes its place.
function FruitTradeService.Client:RemoveFruit(player: Player): boolean
	local data = getCustomer(player)
	if not data then
		return false
	end

	local fruits = data.Data.DevilFruits
	if fruits.Slot1.Name == FruitConfig.EmptyName then
		NotifyService:Send(player, "You have no devil fruit to remove", "Error")
		return false
	end
	if not data:TrySpend("Economy.DFCoins", SELLER.RemoveFruitCoins) then
		NotifyService:Send(player, "Not enough DF Coins", "Error")
		return false
	end

	FruitLogService:Record(player, "Removed", fruits.Slot1.Name)
	local second = fruits.Slot2
	if second.Name ~= FruitConfig.EmptyName then
		FruitService:SetFruit(player, 1, second.Name, table.clone(data.Data.Affinities.DF2), second.Color)
		FruitService:RemoveFruit(player, 2)
	else
		FruitService:RemoveFruit(player, 1)
	end
	return true
end

-- DF coins a Golden Compass costs right now (half on weekends).
function FruitTradeService:GetGoldenCompassPrice(): number
	return math.ceil(SELLER.GoldenCompassCoins * WorldEventService:GetMultiplier("GoldenCompassPrice"))
end

function FruitTradeService.Client:GetGoldenCompassPrice(_player: Player): number
	return FruitTradeService:GetGoldenCompassPrice()
end

function FruitTradeService.Client:BuyGoldenCompass(player: Player): boolean
	local data = getCustomer(player)
	if not data or not ToolTemplates.Find(SELLER.GoldenCompassItem, ITEM_FOLDER) then
		return false
	end
	if not data:TrySpend("Economy.DFCoins", FruitTradeService:GetGoldenCompassPrice()) then
		NotifyService:Send(player, "Not enough DF Coins", "Error")
		return false
	end

	ToolTemplates.Give(player, SELLER.GoldenCompassItem, ITEM_FOLDER)
	FruitTradeService.GoldenCompassBought:Fire(player)
	return true
end

function FruitTradeService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
	FruitLogService = Knit.GetService("FruitLogService")
	NotifyService = Knit.GetService("NotifyService")
	WorldEventService = Knit.GetService("WorldEventService")
end

function FruitTradeService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		requestLimiter:Forget(player)
	end)
end

return FruitTradeService
