--!strict
--[[
	Top 100 bounties across servers.

	Store traffic is bounded per server, not per player action:
		write  a player's bounty when they leave, and every few minutes if it changed
		read   one sorted page every few minutes, cached and merged with live bounties
	Every store call is pcall'd; a failed read keeps the previous page. In Studio the store
	is never touched and the board only ranks the players of the session.

	The legacy script read the sorted page and resolved 100 user names every 10 seconds on
	every server, and published the result as one long string in ReplicatedStorage.

	Server API
		LeaderboardService:GetTop() -> { { UserId, Name, Bounty } }
		LeaderboardService:IsInTop(player) -> boolean   (also the player attribute "Top100")
		LeaderboardService.Updated (entries)
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local LeaderboardConfig = require(ServerStorage.Server.Configs.LeaderboardConfig)

type PlayerData = PlayerData.PlayerData

export type Entry = { UserId: number, Name: string, Bounty: number }

local LeaderboardService = Knit.CreateService({
	Name = "LeaderboardService",
	Client = {
		-- Fired without arguments when the ranking changed; clients showing it ask again.
		Updated = Knit.CreateSignal(),
	},
})

LeaderboardService.Updated = Signal.new() :: Signal.Signal<{ Entry }>

local DataService

local TOP_ATTRIBUTE = "Top100"

local store: OrderedDataStore? = nil
local entries: { Entry } = {}
-- Last page read from the store: user id -> bounty.
local stored: { [number]: number } = {}
-- Names resolved this session; false marks an id that could not be resolved.
local names: { [number]: string | false } = {}
-- Bounty last saved for each player of this server.
local saved: { [Player]: number } = {}

local function getBounty(data: PlayerData): number
	return math.max(0, math.floor(data.Data.Combat.Bounty))
end

local function resolveName(userId: number): string?
	local known = names[userId]
	if known ~= nil then
		return known or nil
	end

	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and type(name) == "string" then name else false
	return names[userId] or nil
end

local function save(player: Player, bounty: number)
	local target = store
	if not target or saved[player] == bounty then
		return
	end
	-- A player who never earned bounty has no business in the store.
	if bounty <= 0 and stored[player.UserId] == nil and saved[player] == nil then
		return
	end

	local ok, problem = pcall(target.SetAsync, target, tostring(player.UserId), bounty)
	if ok then
		saved[player] = bounty
	else
		warn(`[Leaderboard] could not save {player.Name}: {problem}`)
	end
end

local function readStore()
	local target = store
	if not target then
		return
	end

	local ok, pages = pcall(target.GetSortedAsync, target, false, LeaderboardConfig.Size)
	if not ok then
		warn(`[Leaderboard] could not read the top: {pages}`)
		return
	end

	local page: { [number]: number } = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId and type(item.value) == "number" then
			page[userId] = item.value
			-- Yields the first time an id is seen; cached for the rest of the session.
			resolveName(userId)
		end
	end
	stored = page
end

local function sameRanking(a: { Entry }, b: { Entry }): boolean
	if #a ~= #b then
		return false
	end
	for index, entry in a do
		if entry.UserId ~= b[index].UserId or entry.Bounty ~= b[index].Bounty then
			return false
		end
	end
	return true
end

-- Ranks the stored page with the live bounties of this server on top of it.
local function rebuild()
	local bounties = table.clone(stored)
	for _, player in Players:GetPlayers() do
		local data = DataService:GetData(player)
		if data then
			bounties[player.UserId] = getBounty(data)
			names[player.UserId] = player.Name
		end
	end

	local ranking: { Entry } = {}
	for userId, bounty in bounties do
		local name = names[userId]
		if name then
			table.insert(ranking, { UserId = userId, Name = name, Bounty = bounty })
		end
	end
	table.sort(ranking, function(a: Entry, b: Entry)
		if a.Bounty ~= b.Bounty then
			return a.Bounty > b.Bounty
		end
		return a.UserId < b.UserId
	end)
	for index = #ranking, LeaderboardConfig.Size + 1, -1 do
		ranking[index] = nil
	end

	local changed = not sameRanking(entries, ranking)
	entries = ranking

	local inTop: { [number]: boolean } = {}
	for _, entry in ranking do
		inTop[entry.UserId] = true
	end
	for _, player in Players:GetPlayers() do
		local flag = inTop[player.UserId] == true
		if player:GetAttribute(TOP_ATTRIBUTE) ~= flag then
			player:SetAttribute(TOP_ATTRIBUTE, flag)
		end
	end

	if changed then
		LeaderboardService.Updated:Fire(ranking)
		LeaderboardService.Client.Updated:FireAll()
	end
end

local function saveChanged()
	for _, player in Players:GetPlayers() do
		local data = DataService:GetData(player)
		if data and saved[player] ~= getBounty(data) then
			save(player, getBounty(data))
			task.wait(LeaderboardConfig.WriteSpacing)
		end
	end
end

function LeaderboardService:GetTop(): { Entry }
	return entries
end

function LeaderboardService:IsInTop(player: Player): boolean
	return player:GetAttribute(TOP_ATTRIBUTE) == true
end

-- The cached ranking; never a store request.
function LeaderboardService.Client:GetTop(_player: Player): { Entry }
	return entries
end

function LeaderboardService:KnitInit()
	DataService = Knit.GetService("DataService")

	if not RunService:IsStudio() then
		local ok, result = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, LeaderboardConfig.StoreName)
		if ok then
			store = result
		else
			warn(`[Leaderboard] store unavailable: {result}`)
		end
	end
end

function LeaderboardService:KnitStart()
	DataService.Releasing:Connect(function(player: Player, data: PlayerData)
		-- The session is torn down right after this signal: read now, save in its own thread.
		local bounty = getBounty(data)
		task.spawn(function()
			save(player, bounty)
			saved[player] = nil
		end)
	end)

	task.spawn(function()
		local tick = 0
		while true do
			if tick % LeaderboardConfig.ReadEveryTicks == 0 then
				readStore()
			end
			if tick > 0 and tick % LeaderboardConfig.WriteEveryTicks == 0 then
				saveChanged()
			end
			rebuild()
			tick += 1
			task.wait(LeaderboardConfig.TickInterval)
		end
	end)
end

return LeaderboardService
