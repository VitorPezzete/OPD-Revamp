--!strict
--[[
	Numbers of the devil fruit economy that the legacy game kept hardcoded in
	StorageServer, Bounds, SellerNPC, Sam_Quest, the merchants' Retum scripts, the
	juicing bowls and DropHandler. The client reads them to show prices; the server is
	the only one that charges them.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)

export type SellCurrency = "Beri" | "Gems" | "DFCoins"
export type SellPrices = { Beri: number, Gems: number?, DFCoins: number? }

local FruitEconomyConfig = {}

FruitEconomyConfig.Skills = table.freeze({ "Defense", "Melee", "Sniper", "Sword" })

FruitEconomyConfig.Storage = table.freeze({
	SlotCount = 12,
	UnlockGems = 500,
	-- A slot is locked for this long after a fruit goes in or is requested out.
	CooldownSeconds = 60,
	-- "Processing": a withdrawal lands this long after the request, if the character lived.
	WithdrawSeconds = 10,
})

FruitEconomyConfig.Bound = table.freeze({
	-- The data has three bound slots (the legacy game only ever opened the first).
	SlotCount = 3,
	UnlockGems = 2000,
	DebounceSeconds = 2,
})

-- What SellerMerchant pays per rarity. Only Rare and above sell for gems or DF coins.
FruitEconomyConfig.SellPrices = table.freeze({
	Common = table.freeze({ Beri = 25000 }),
	Uncommon = table.freeze({ Beri = 100000 }),
	Rare = table.freeze({ Beri = 1000000, Gems = 50, DFCoins = 1 }),
	UltraRare = table.freeze({ Beri = 15000000, Gems = 500, DFCoins = 10 }),
} :: { [string]: SellPrices })

-- Event fruits sat in an "UltraRareFruits" folder, so the old lookup priced them as ultra rares.
function FruitEconomyConfig.GetSellPrices(fruitName: string): SellPrices?
	local fruit = FruitConfig.Fruits[fruitName]
	if not fruit then
		return nil
	end
	local rarity = if fruit.Rarity == "Event" then "UltraRare" else fruit.Rarity
	return FruitEconomyConfig.SellPrices[rarity]
end

-- Fruits whose movements are written to the audit log.
function FruitEconomyConfig.IsTracked(fruitName: string): boolean
	local fruit = FruitConfig.Fruits[fruitName]
	return fruit ~= nil and (fruit.Rarity == "Rare" or fruit.Rarity == "UltraRare" or fruit.Rarity == "Event")
end

FruitEconomyConfig.Seller = table.freeze({
	Merchant = "SellerMerchant",
	RemoveFruitCoins = 2,
	-- Before the weekend modifier (WorldEventService:GetMultiplier("GoldenCompassPrice")).
	GoldenCompassCoins = 14,
	GoldenCompassItem = "Golden Compass",
})

FruitEconomyConfig.Pickup = table.freeze({
	Range = 10,
	-- Fruits of a dead character land this far around the body, this high above it.
	DeathScatter = 10,
	DeathHeight = 10,
})

-- Tools the drop button accepts (matched anywhere in the name, case-insensitive).
FruitEconomyConfig.Drop = table.freeze({
	Keywords = table.freeze({ "Compass", "Box", "Juice", "Cider", "Lemonade", "Smoothie" }),
	CooldownSeconds = 1.5,
})

function FruitEconomyConfig.IsDroppable(toolName: string): boolean
	local lower = string.lower(toolName)
	for _, keyword in FruitEconomyConfig.Drop.Keywords do
		if string.find(lower, string.lower(keyword), 1, true) then
			return true
		end
	end
	return false
end

FruitEconomyConfig.Affinity = table.freeze({
	Merchant = "AffinityMerchant",
	BeriCost = 100000,
	GemCost = 10,
	-- Each locked affinity doubles the price; at least one must stay unlocked.
	MaxLocks = 3,
	SpinSeconds = 7,
	SkipSpinGamePassId = 1704493370,
})

function FruitEconomyConfig.GetRerollCost(currency: "Beri" | "Gems", lockCount: number): number
	local affinity = FruitEconomyConfig.Affinity
	local base = if currency == "Gems" then affinity.GemCost else affinity.BeriCost
	return base * 2 ^ lockCount
end

-- Sam's compass tokens (QuestMerchant) and the friend's strange compasses (FriendMerchant).
FruitEconomyConfig.Tokens = table.freeze({
	QuestMerchants = table.freeze({ "QuestMerchant", "QuestMerchant2" }),
	AuraMerchant = "FriendMerchant",
	-- Seconds for one token, before the weekend modifier
	-- (WorldEventService:GetMultiplier("CompassTokenTime")); each Expertise level takes some off.
	Seconds = 30 * 60,
	SecondsPerExpertiseLevel = 3,
	ClaimAmounts = table.freeze({ 1, 10 }),

	CompassItem = "Compass",
	-- Private server owners: every VIPRushGoal claimed compasses add a golden one.
	GoldenCompassItem = "Golden Compass",
	VIPRushGoal = 50,

	StrangeCompassItem = "Strange Compass",
	GoldenStrangeCompassItem = "??? Strange Compass",
	AuraRushGoal = 50,
	-- Goal while the "Stranger Compasses" event flag is on.
	AuraRushEventGoal = 25,
	StrangerCompassEvent = false,

	-- Player attribute holding the server time (Workspace:GetServerTimeNow) of the next token.
	ReadyAttribute = "CompassTokenAt",
})

function FruitEconomyConfig.GetAuraRushGoal(): number
	local tokens = FruitEconomyConfig.Tokens
	return if tokens.StrangerCompassEvent then tokens.AuraRushEventGoal else tokens.AuraRushGoal
end

FruitEconomyConfig.Juicing = table.freeze({
	-- CollectionService tag of every juicing bowl; the attribute is true while it spins.
	Tag = "JuicingBowl",
	MixingAttribute = "Mixing",
	MixSeconds = 5,
	Range = 32,
	Recipes = table.freeze({
		["Green Apple"] = "Sour Juice",
		Pumpkin = "Pumpkin Juice",
		Banana = "Banana Juice",
		Coconut = "Coconut Milk",
		Cantaloupe = "Fruit Juice",
		Melon = "Fruit Juice",
		["Prickly Pear"] = "Pear Juice",
		Apple = "Apple Juice",
	} :: { [string]: string }),
})

return table.freeze(FruitEconomyConfig)
