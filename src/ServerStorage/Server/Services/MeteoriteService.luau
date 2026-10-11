--!strict
--[[
	The Meteorite Sword hunt: a hidden weapon unlocked by four feats, saved in data.SSM
	as four booleans.

		1. Compass token capacity of 3 or more.
		2. Three compass treasures dug up within a minute of each other.
		3. Buying a Golden Compass from the seller.
		4. Selling a rare fruit to the seller.

	Server-only: the systems that own those actions report them,

		MeteoriteService:Progress(player, "Compass")         -- a compass treasure was dug up
		MeteoriteService:Progress(player, "GoldenCompass")   -- bought from the seller
		MeteoriteService:Progress(player, "Rare")            -- rare fruit sold

	and feat 1 is observed from the player's data. When all four are done the weapon is
	added to Items and the player is told.

	Legacy: the feats were re-read from a "true,false,..." string on every call and the
	capacity feat was only noticed when another feat happened to fire.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local WorldObjectConfig = require(ServerStorage.Server.Configs.WorldObjectConfig)

type PlayerData = PlayerData.PlayerData
export type Feat = "Compass" | "GoldenCompass" | "Rare"

local CONFIG = WorldObjectConfig.Meteorite
local FEAT_TOKENS, FEAT_COMPASS, FEAT_GOLDEN, FEAT_RARE = 1, 2, 3, 4
local FEAT_COUNT = 4

local MeteoriteService = Knit.CreateService({
	Name = "MeteoriteService",
	Client = {},
})

-- (player) when the sword is unlocked.
MeteoriteService.Unlocked = Signal.new() :: Signal.Signal<Player>

local DataService
local NotifyService

-- Times (os.clock) of the recent compass finds of each player.
local compassFinds: { [Player]: { number } } = {}

local function isUnlocked(data: PlayerData): boolean
	return data.Data.Items[CONFIG.Weapon] == true
end

local function complete(player: Player, data: PlayerData, feat: number)
	if isUnlocked(data) then
		return
	end

	local feats = table.clone(data.Data.SSM)
	if feats[feat] then
		return
	end
	feats[feat] = true
	data:Set("SSM", feats)

	for index = 1, FEAT_COUNT do
		if not feats[index] then
			return
		end
	end

	data:Set(`Items.{CONFIG.Weapon}`, true)
	MeteoriteService.Unlocked:Fire(player)
end

local function countCompassFind(player: Player): boolean
	local now = os.clock()
	local finds = compassFinds[player] or {}
	compassFinds[player] = finds

	-- Each find only counts for CompassWindow seconds.
	for index = #finds, 1, -1 do
		if now - finds[index] > CONFIG.CompassWindow then
			table.remove(finds, index)
		end
	end
	table.insert(finds, now)
	return #finds >= CONFIG.CompassFinds
end

function MeteoriteService:Progress(player: Player, feat: Feat)
	local data = DataService:GetData(player)
	if not data or isUnlocked(data) then
		return
	end

	if feat == "Compass" then
		if not data.Data.SSM[FEAT_COMPASS] and countCompassFind(player) then
			complete(player, data, FEAT_COMPASS)
		end
	elseif feat == "GoldenCompass" then
		complete(player, data, FEAT_GOLDEN)
	elseif feat == "Rare" then
		complete(player, data, FEAT_RARE)
	end
end

-- The four feats, in the order of the header. For UI or debugging.
function MeteoriteService:GetFeats(player: Player): { boolean }?
	local data = DataService:GetData(player)
	return if data then table.clone(data.Data.SSM) else nil
end

function MeteoriteService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
end

function MeteoriteService:KnitStart()
	local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
	local FruitTradeService = Knit.GetService("FruitTradeService")
	FruitTradeService.GoldenCompassBought:Connect(function(player: Player)
		MeteoriteService:Progress(player, "GoldenCompass")
	end)
	FruitTradeService.Sold:Connect(function(player: Player, fruitName: string)
		local definition = FruitConfig.Fruits[fruitName]
		if definition and (definition.Rarity == "Rare" or definition.Rarity == "UltraRare") then
			MeteoriteService:Progress(player, "Rare")
		end
	end)

	DataService:ObserveData(function(player: Player, data: PlayerData)
		local function checkTokens()
			if data.Data.CompassTokens.Limit >= CONFIG.CompassTokenLimit then
				complete(player, data, FEAT_TOKENS)
			end
		end
		data:Observe("CompassTokens.Limit", checkTokens)
		checkTokens()
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		compassFinds[player] = nil
	end)
end

return MeteoriteService
