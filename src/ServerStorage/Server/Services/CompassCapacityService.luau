--!strict
--[[
	Capacity of Sam's compass tokens (CompassTokens.Limit), bought with gems at Sam.

	Only the capacity upgrade lives here; earning and spending the tokens belongs to the
	quest system. The price grows with the capacity already owned and is always computed
	here. The legacy remote took no arguments either, but it could be fired from anywhere
	on the map and indexed the data of players that were still loading.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local CompassCapacityService = Knit.CreateService({
	Name = "CompassCapacityService",
	Client = {},
})

local DataService
local NotifyService

local upgradeLimiter = RateLimiter.new(3, 1)

local function isAtSam(player: Player): boolean
	for _, merchantName in InventoryConfig.CompassCapacity.Merchants do
		if Proximity.GetMerchant(player, merchantName) then
			return true
		end
	end
	return false
end

function CompassCapacityService:GetCapacityCost(player: Player): number?
	local data = DataService:GetData(player)
	return if data then InventoryConfig.GetCompassCapacityCost(data.Data.CompassTokens.Limit) else nil
end

-- Buys one more token of capacity. Returns whether the purchase went through.
function CompassCapacityService.Client:UpgradeCapacity(player: Player): boolean
	if not upgradeLimiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	if not data or not isAtSam(player) then
		return false
	end

	local cost = InventoryConfig.GetCompassCapacityCost(data.Data.CompassTokens.Limit)
	if not data:TrySpend("Economy.Gems", cost) then
		NotifyService:Send(player, "Not enough Gems", "Error")
		return false
	end

	data:Increment("CompassTokens.Limit", 1)
	return true
end

function CompassCapacityService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
end

function CompassCapacityService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		upgradeLimiter:Forget(player)
	end)
end

return CompassCapacityService
