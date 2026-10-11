--!strict
--[[
	AffinityMerchant: rerolls the four affinities of an eaten fruit.

	The client names the fruit slot, the currency and which affinities to keep; the
	price (doubling per lock), the odds and the roll are the server's. The result lands
	after the spin time, or at once for owners of the Skip Spin pass who ask for it.

	Fixed from the legacy remote:
	- Locking all four affinities was only refused by the client; the server charged
	  16x the price and rolled nothing.
	- An empty fruit slot could be rerolled, and several spins could run at once.
	- No check that the player was at the merchant.
	- Owning the pass was asked to MarketplaceService (a web call) on every roll.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local FruitOddsConfig = require(ServerStorage.Server.Configs.FruitOddsConfig)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local AFFINITY = FruitEconomyConfig.Affinity
local SKILLS = FruitEconomyConfig.Skills
local MERCHANT_RANGE = 35

local CURRENCY_PATHS: { [string]: string } = {
	Beri = "Economy.Beri",
	Gems = "Economy.Gems",
}

local AffinityService = Knit.CreateService({
	Name = "AffinityService",
	Client = {},
})

-- (player, fruitSlot) when a paid reroll has been applied.
AffinityService.Rerolled = Signal.new() :: Signal.Signal<Player, number>

local DataService
local NotifyService

local requestLimiter = RateLimiter.new(3, 1)
local spinning: { [Player]: boolean } = {}
local random = Random.new()

local function roll(odds: { FruitOddsConfig.Weighted }): number
	local total = 0
	for _, entry in odds do
		total += entry.Weight
	end

	local pick = random:NextNumber() * total
	for _, entry in odds do
		pick -= entry.Weight
		if pick <= 0 then
			return entry.Value
		end
	end
	return odds[#odds].Value
end

-- { Defense = true, ... } from client input: only real booleans of known skills count.
local function readLocks(input: unknown): ({ [string]: boolean }?, number)
	if type(input) ~= "table" then
		return nil, 0
	end

	local locks = {}
	local count = 0
	for _, skill in SKILLS do
		local value = (input :: any)[skill]
		if value ~= nil and type(value) ~= "boolean" then
			return nil, 0
		end
		locks[skill] = value == true
		if value == true then
			count += 1
		end
	end
	return locks, count
end

local function apply(player: Player, data: any, fruitSlot: number, fruitName: string, locks: { [string]: boolean }, currency: string, cost: number)
	spinning[player] = nil
	if player.Parent ~= Players or DataService:GetData(player) ~= data or not data:IsActive() then
		return
	end

	-- The fruit left the slot during the spin: nothing to reroll, the price goes back.
	if data.Data.DevilFruits[`Slot{fruitSlot}`].Name ~= fruitName then
		data:Increment(CURRENCY_PATHS[currency], cost)
		return
	end

	local odds = FruitOddsConfig.RerollOdds[currency]
	local affinities = table.clone(data.Data.Affinities[`DF{fruitSlot}`])
	for _, skill in SKILLS do
		if not locks[skill] then
			affinities[skill] = roll(odds)
		end
	end
	data:Set(`Affinities.DF{fruitSlot}`, affinities)
	AffinityService.Rerolled:Fire(player, fruitSlot)
end

-- Returns whether the reroll was paid for and started.
function AffinityService.Client:Reroll(player: Player, fruitSlot: unknown, currency: unknown, locks: unknown, skip: unknown): boolean
	if (fruitSlot ~= 1 and fruitSlot ~= 2) or type(currency) ~= "string" or not CURRENCY_PATHS[currency] then
		return false
	end
	local lockTable, lockCount = readLocks(locks)
	if not lockTable or lockCount > AFFINITY.MaxLocks then
		return false
	end

	local data = DataService:GetData(player)
	if not data or spinning[player] or not requestLimiter:Consume(player) then
		return false
	end
	if not Proximity.GetMerchant(player, AFFINITY.Merchant, MERCHANT_RANGE) then
		return false
	end

	local slot = fruitSlot :: number
	local fruitName: string = data.Data.DevilFruits[`Slot{slot}`].Name
	if fruitName == FruitConfig.EmptyName then
		return false
	end

	local cost = FruitEconomyConfig.GetRerollCost(currency :: any, lockCount)
	if not data:TrySpend(CURRENCY_PATHS[currency], cost) then
		NotifyService:Send(player, if currency == "Gems" then "Not enough Gems" else "Not enough Beri", "Error")
		return false
	end

	spinning[player] = true
	if skip == true and data.Data.GamePasses.SkipSpin then
		apply(player, data, slot, fruitName, lockTable, currency :: string, cost)
	else
		task.delay(AFFINITY.SpinSeconds, apply, player, data, slot, fruitName, lockTable, currency :: string, cost)
	end
	return true
end

function AffinityService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
end

function AffinityService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		requestLimiter:Forget(player)
		spinning[player] = nil
	end)
end

return AffinityService
