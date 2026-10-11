--!strict
--[[
	Fruit storage (12 slots holding fruit items) and bound fruits (an eaten fruit set
	aside, swapped back in later).

	Storage keeps the whole item: fruit, the four affinity scores, the aura and its id.
	Every action is one server step without a yield between "the item leaves the world"
	and "the data changes":

	- Store:    the held Tool is destroyed, then the slot is written.
	- Withdraw: the slot keeps the fruit during the 10 second "processing" wait; when it
	            ends the slot is cleared and the Tool is created in the same step. If
	            the character died, changed or left meanwhile, nothing happened at all.

	The legacy remote emptied the slot first and waited ten seconds polling the
	character every 0.1s to decide whether to write the fruit back; leaving or resetting
	in that window, or racing two requests against the cooldown value, lost or doubled
	fruits. It also bought a slot whenever a locked one was clicked with 500 gems.

	Binding moves an eaten fruit between a fruit slot and the bound slot and always
	kills the character, as before. Unbinding into the second fruit slot now requires
	Legendary Mode: the legacy script did not check, which was a way around it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local FruitItemCodec = require(ReplicatedStorage.Shared.Util.FruitItemCodec)
local Optional = require(ReplicatedStorage.Shared.Util.Optional)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local STORAGE = FruitEconomyConfig.Storage
local BOUND = FruitEconomyConfig.Bound
local EMPTY = FruitItemCodec.Empty

local FruitStorageService = Knit.CreateService({
	Name = "FruitStorageService",
	Client = {
		-- (slot: number, secondsLeft: number, withdrawing: boolean) when a slot starts its cooldown.
		Cooldown = Knit.CreateSignal(),
	},
})

local DataService
local CharacterService
local FruitService
local FruitLogService
local NotifyService
-- nil while trading is switched off (TradeConfig.Enabled): nobody is trading then.
local TradeService

local requestLimiter = RateLimiter.new(4, 2)
local bindLimiter = RateLimiter.new(1, 1 / BOUND.DebounceSeconds)

-- os.clock() at which each slot of a player can be used again. Session-only, as before.
local readyAt: { [Player]: { [string]: number } } = {}
-- Slots whose withdrawal is being processed: the fruit is still in the slot, but spoken for.
local withdrawing: { [Player]: { [string]: boolean } } = {}
-- Slots whose withdrawal is being processed: the fruit is still in the slot, but spoken for.
local withdrawing: { [Player]: { [string]: boolean } } = {}
-- Slots whose withdrawal is being processed: the fruit is still in the slot, but spoken for.
local withdrawing: { [Player]: { [string]: boolean } } = {}
-- Slots whose withdrawal is being processed: the fruit is still in the slot, but spoken for.
local withdrawing: { [Player]: { [string]: boolean } } = {}
-- Slots whose withdrawal is being processed: the fruit is still in the slot, but spoken for.
local withdrawing: { [Player]: { [string]: boolean } } = {}

-- "3" for a valid slot number, nil for anything else a client may send.
local function toSlotKey(slot: unknown, count: number): string?
	if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 or slot < 1 or slot > count then
		return nil
	end
	return tostring(slot)
end

local function getRemaining(player: Player, key: string): number
	local slots = readyAt[player]
	return math.max(0, (slots and slots[key] or 0) - os.clock())
end

local function startCooldown(player: Player, key: string, withdrawing: boolean)
	local slots = readyAt[player]
	if not slots then
		slots = {}
		readyAt[player] = slots
	end
	slots[key] = os.clock() + STORAGE.CooldownSeconds
	FruitStorageService.Client.Cooldown:Fire(player, tonumber(key), STORAGE.CooldownSeconds, withdrawing)
end

local function getLivingEntity(player: Player): any
	local entity = CharacterService:GetPlayerEntity(player)
	return if entity and not entity.Dead then entity else nil
end

-- Buys a locked slot.
function FruitStorageService.Client:Unlock(player: Player, slot: unknown): boolean
	local key = toSlotKey(slot, STORAGE.SlotCount)
	local data = DataService:GetData(player)
	if not key or not data or not requestLimiter:Consume(player) then
		return false
	end

	local stored = data.Data.Storages[key]
	if not stored or stored.Unlocked then
		return false
	end
	if not data:TrySpend("Economy.Gems", STORAGE.UnlockGems) then
		NotifyService:Send(player, "Not enough Gems", "Error")
		return false
	end

	data:Set(`Storages.{key}.Unlocked`, true)
	return true
end

-- Puts the fruit the character is holding into an empty slot.
function FruitStorageService.Client:Store(player: Player, slot: unknown): boolean
	local key = toSlotKey(slot, STORAGE.SlotCount)
	local data = DataService:GetData(player)
	local entity = getLivingEntity(player)
	if not key or not data or not entity or not requestLimiter:Consume(player) then
		return false
	end

	local stored = data.Data.Storages[key]
	if not stored or not stored.Unlocked or stored.Item ~= EMPTY or getRemaining(player, key) > 0 then
		return false
	end

	local tool = entity.Model:FindFirstChildOfClass("Tool")
	local item = tool and FruitService:GetItem(tool)
	if not tool or not item or not data:IsActive() then
		return false
	end

	local encoded = FruitItemCodec.EncodeItem(item)
	local id = FruitLogService:GetId(tool, player) or EMPTY
	FruitLogService:RecordTool(player, "Stored", tool)

	-- The item stops existing before the slot is written: a failure here can lose the
	-- fruit but never leave it in two places.
	tool:Destroy()
	data:Set(`Storages.{key}`, { Item = encoded, ID = id, Unlocked = true })

	startCooldown(player, key, false)
	return true
end

-- Starts taking the fruit out of a slot; it reaches the backpack after the processing time.
function FruitStorageService.Client:Withdraw(player: Player, slot: unknown): boolean
	local key = toSlotKey(slot, STORAGE.SlotCount)
	local data = DataService:GetData(player)
	local entity = getLivingEntity(player)
	if not key or not data or not entity or not requestLimiter:Consume(player) then
		return false
	end

	local stored = data.Data.Storages[key]
	if not stored or not stored.Unlocked or getRemaining(player, key) > 0 then
		return false
	end
	local encoded = stored.Item
	if not FruitItemCodec.DecodeItem(encoded) then
		return false
	end
	-- A fruit on the table of a trade cannot also be on its way to the backpack.
	if TradeService and TradeService:IsTrading(player) then
		NotifyService:Send(player, "Finish your trade first", "Error")
		return false
	end

	-- The cooldown is what makes the pending withdrawal exclusive: nothing can touch
	-- this slot again before it has landed or been dropped.
	startCooldown(player, key, true)
	local character = entity.Model
	local pending = withdrawing[player]
	if not pending then
		pending = {}
		withdrawing[player] = pending
	end
	pending[key] = true

	task.delay(STORAGE.WithdrawSeconds, function()
		pending[key] = nil
		if player.Parent ~= Players or DataService:GetData(player) ~= data or not data:IsActive() then
			return
		end

		local current = data.Data.Storages[key]
		local item = FruitItemCodec.DecodeItem(current.Item)
		local currentEntity = getLivingEntity(player)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if current.Item ~= encoded or not item or not backpack then
			return
		end
		if not currentEntity or currentEntity.Model ~= character then
			NotifyService:Send(player, "You died: the fruit stayed in storage", "Error")
			return
		end

		local tool = FruitService:CreateItem(item.FruitName, item.Scores, item.HasAura)
		if not tool then
			return
		end

		local id = current.ID
		data:Set(`Storages.{key}`, { Item = EMPTY, ID = EMPTY, Unlocked = true })
		FruitLogService:Restore(tool, id, player)
		tool.Parent = backpack
		FruitLogService:RecordTool(player, "Withdrawn", tool)
	end)
	return true
end

-- Seconds left on each slot that is cooling down, for a screen that just opened.
function FruitStorageService.Client:GetCooldowns(player: Player): { [string]: number }
	local result = {}
	for key in readyAt[player] or {} do
		local remaining = getRemaining(player, key)
		if remaining > 0 then
			result[key] = remaining
		end
	end
	return result
end

function FruitStorageService.Client:UnlockBound(player: Player, slot: unknown): boolean
	local key = toSlotKey(slot, BOUND.SlotCount)
	local data = DataService:GetData(player)
	if not key or not data or not requestLimiter:Consume(player) then
		return false
	end

	local bound = data.Data.Bounds[key]
	if not bound or bound.Unlocked then
		return false
	end
	if not data:TrySpend("Economy.Gems", BOUND.UnlockGems) then
		NotifyService:Send(player, "Not enough Gems", "Error")
		return false
	end

	data:Set(`Bounds.{key}.Unlocked`, true)
	return true
end

local function encodeFruitSlot(data: any, fruitSlot: number): string
	local fruit = data.Data.DevilFruits[`Slot{fruitSlot}`]
	local affinities = data.Data.Affinities[`DF{fruitSlot}`]
	return FruitItemCodec.EncodeBound({
		FruitName = fruit.Name,
		Affinities = affinities,
		Color = fruit.Color,
	})
end

--[[
	Empty bound slot: the last eaten fruit (second slot first) goes into it.
	Filled bound slot: its fruit comes back. It takes the first fruit slot when that is
	empty; otherwise it takes the second one and whatever was there becomes bound.
	Either way the character dies.
]]
function FruitStorageService.Client:Bind(player: Player, slot: unknown): boolean
	local key = toSlotKey(slot, BOUND.SlotCount)
	local data = DataService:GetData(player)
	local entity = getLivingEntity(player)
	if not key or not data or not entity or not data:IsActive() then
		return false
	end

	local bound = data.Data.Bounds[key]
	if not bound or not bound.Unlocked or not bindLimiter:Consume(player) then
		return false
	end
	if TradeService and TradeService:IsTrading(player) then
		NotifyService:Send(player, "Finish your trade first", "Error")
		return false
	end

	local fruits = data.Data.DevilFruits
	local hasFirst = fruits.Slot1.Name ~= FruitConfig.EmptyName
	local hasSecond = fruits.Slot2.Name ~= FruitConfig.EmptyName

	if bound.Fruit == EMPTY then
		local source = if hasSecond then 2 elseif hasFirst then 1 else nil
		if not source then
			return false
		end

		local fruitName = fruits[`Slot{source}`].Name
		local encoded = encodeFruitSlot(data, source)
		FruitService:RemoveFruit(player, source)
		data:Set(`Bounds.{key}.Fruit`, encoded)
		FruitLogService:Record(player, "Bound", fruitName)
	else
		local stored = FruitItemCodec.DecodeBound(bound.Fruit)
		if not stored then
			NotifyService:Send(player, "This bound fruit can no longer be used", "Error")
			return false
		end

		local target = if hasFirst then 2 else 1
		if target == 2 and not data.Data.Combat.LegendaryMode then
			NotifyService:Send(player, "You need Legendary Mode to hold a second fruit", "Error")
			return false
		end

		data:Set(`Bounds.{key}.Fruit`, if target == 2 and hasSecond then encodeFruitSlot(data, 2) else EMPTY)
		FruitService:SetFruit(player, target, stored.FruitName, stored.Affinities, stored.Color)
		FruitLogService:Record(player, "Unbound", stored.FruitName)
	end

	entity:Kill()
	return true
end

-- Whether a storage slot ("1"..) is in the middle of a withdrawal.
function FruitStorageService:IsWithdrawing(player: Player, key: string): boolean
	local pending = withdrawing[player]
	return pending ~= nil and pending[key] == true
end

-- Whether a storage slot ("1"..) is in the middle of a withdrawal.
function FruitStorageService:IsWithdrawing(player: Player, key: string): boolean
	local pending = withdrawing[player]
	return pending ~= nil and pending[key] == true
end

-- Whether a storage slot ("1"..) is in the middle of a withdrawal.
function FruitStorageService:IsWithdrawing(player: Player, key: string): boolean
	local pending = withdrawing[player]
	return pending ~= nil and pending[key] == true
end

-- Whether a storage slot ("1"..) is in the middle of a withdrawal.
function FruitStorageService:IsWithdrawing(player: Player, key: string): boolean
	local pending = withdrawing[player]
	return pending ~= nil and pending[key] == true
end

-- Whether a storage slot ("1"..) is in the middle of a withdrawal.
function FruitStorageService:IsWithdrawing(player: Player, key: string): boolean
	local pending = withdrawing[player]
	return pending ~= nil and pending[key] == true
end

function FruitStorageService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
	FruitLogService = Knit.GetService("FruitLogService")
	NotifyService = Knit.GetService("NotifyService")
	TradeService = Optional.Service("TradeService")
end

function FruitStorageService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		requestLimiter:Forget(player)
		bindLimiter:Forget(player)
		readyAt[player] = nil
		withdrawing[player] = nil
		withdrawing[player] = nil
		withdrawing[player] = nil
		withdrawing[player] = nil
		withdrawing[player] = nil
	end)
end

return FruitStorageService
