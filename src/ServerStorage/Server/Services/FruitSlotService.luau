--!strict
--[[
	Swapping the two devil fruit slots (the button on the second fruit of the inventory).

	The fruit, its aura color and its affinities move together, so the ability keys of
	both fruits trade places and nothing else changes. The request has no arguments.

	The server script behind the legacy SwapServer remote was not in the dump; what is
	known comes from its client: the button only exists while the second slot is filled,
	and the server answered with a number that the button showed as a countdown.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local FruitSlotService = Knit.CreateService({
	Name = "FruitSlotService",
	Client = {},
})

-- (player) after the slots traded places.
FruitSlotService.Swapped = Signal.new() :: Signal.Signal<Player>

local DataService
local CharacterService
local FruitService

local requestLimiter = RateLimiter.new(4, 1)
-- os.clock() at which each player may swap again. Session-only, as in the legacy game.
local readyAt: { [Player]: number } = {}

local function getRemaining(player: Player): number
	return math.max(0, math.ceil((readyAt[player] or 0) - os.clock()))
end

function FruitSlotService:CanSwap(player: Player): boolean
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead then
		return false
	end
	-- The second slot only fills in Legendary Mode; with it empty there is nothing to trade.
	return data.Data.DevilFruits.Slot2.Name ~= FruitConfig.EmptyName
end

function FruitSlotService:Swap(player: Player): boolean
	local data = DataService:GetData(player)
	if not data or not FruitSlotService:CanSwap(player) then
		return false
	end

	local fruits = data.Data.DevilFruits
	local affinities = data.Data.Affinities
	local first, second = fruits.Slot1, fruits.Slot2
	local firstAffinity, secondAffinity = affinities.DF1, affinities.DF2

	data:Set("Affinities.DF1", secondAffinity)
	data:Set("Affinities.DF2", firstAffinity)
	data:Set("DevilFruits.Slot1", second)
	data:Set("DevilFruits.Slot2", first)

	-- Passives and ability bindings follow FruitChanged, slot by slot.
	FruitService.FruitChanged:Fire(player, 1, second.Name)
	FruitService.FruitChanged:Fire(player, 2, first.Name)
	FruitSlotService.Swapped:Fire(player)
	return true
end

-- Swaps if allowed. Returns the seconds until the next swap: the full cooldown after a
-- swap, what is left of it when called too early, 0 when the swap was refused.
function FruitSlotService.Client:Swap(player: Player): number
	if not requestLimiter:Consume(player) then
		return getRemaining(player)
	end

	local remaining = getRemaining(player)
	if remaining > 0 then
		return remaining
	end
	if not FruitSlotService:Swap(player) then
		return 0
	end

	readyAt[player] = os.clock() + InventoryConfig.FruitSwapCooldown
	return InventoryConfig.FruitSwapCooldown
end

function FruitSlotService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
end

function FruitSlotService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		requestLimiter:Forget(player)
		readyAt[player] = nil
	end)
end

return FruitSlotService
