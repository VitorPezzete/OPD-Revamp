--!strict
--[[
	Treasure caches fished out of the sea (Copper / Silver / Gold / Platinum).

	A cache is a Tool; using it opens it: food, maybe a drink, a compass for the best
	one, plus Beri and gems. The contents are rolled here when it is opened and the
	currency goes straight to the saved data.

	Server API
		CacheService:Give(player, cacheName) -> Tool?

	Legacy bug fixed: in a private server the cache script returned before destroying the
	tool, after having handed out the items, and left a dead cache in the backpack.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)

-- Folders of ReplicatedStorage.Assets.Models searched first for each kind of template.
local CACHE_FOLDER = "Items"
local FOOD_FOLDER = "Items"

local CacheService = Knit.CreateService({
	Name = "CacheService",
	Client = {},
})

-- Private servers get the items but no currency.
CacheService.RewardsEnabled = game.PrivateServerOwnerId == 0

local DataService
local CharacterService
local NotifyService

local random = Random.new()
-- Caches handed out by this service and not opened yet.
local caches: { [Tool]: string } = {}

local function open(player: Player, tool: Tool)
	local cacheName = caches[tool]
	local definition = cacheName and FishingConfig.Caches[cacheName]
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not definition or not data or not entity or entity.Dead then
		return
	end

	-- Claimed before anything is given: a second Activated in the same frame finds nothing.
	caches[tool] = nil
	tool:Destroy()

	for _ = 1, random:NextInteger(definition.FruitCount.Min, definition.FruitCount.Max) do
		ToolTemplates.Give(player, definition.Fruits[random:NextInteger(1, #definition.Fruits)], FOOD_FOLDER)
	end
	if random:NextNumber() < definition.GoldenAppleChance then
		ToolTemplates.Give(player, FishingConfig.GoldenApple, FOOD_FOLDER)
	end
	if random:NextNumber() < definition.DrinkChance then
		ToolTemplates.Give(player, definition.Drinks[random:NextInteger(1, #definition.Drinks)], FOOD_FOLDER)
	end
	if definition.Compass then
		ToolTemplates.Give(player, FishingConfig.CompassItem, FOOD_FOLDER)
	end

	if not CacheService.RewardsEnabled then
		return
	end

	local beri = random:NextInteger(definition.Beri.Min, definition.Beri.Max)
	data:Increment("Economy.Beri", beri)
	if definition.Gems > 0 then
		data:Increment("Economy.Gems", definition.Gems)
	end
	NotifyService:Send(
		player,
		if definition.Gems > 0
			then `{cacheName}: {beri} Beri and {definition.Gems} gems!`
			else `{cacheName}: {beri} Beri!`,
		"Success"
	)
end

function CacheService:Give(player: Player, cacheName: string): Tool?
	if not FishingConfig.Caches[cacheName] then
		return nil
	end

	local tool = ToolTemplates.Give(player, cacheName, CACHE_FOLDER)
	if not tool then
		return nil
	end

	caches[tool] = cacheName
	tool.Destroying:Once(function()
		caches[tool] = nil
	end)
	tool.Activated:Connect(function()
		local holder = Players:GetPlayerFromCharacter(tool.Parent)
		if holder then
			open(holder, tool)
		end
	end)

	NotifyService:Send(player, `You fished up a {cacheName}!`, "Success")
	return tool
end

function CacheService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
end

return CacheService
