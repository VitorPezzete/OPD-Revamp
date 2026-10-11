--!strict
--[[
	Publishes the few facts about a player that every other client displays (player list,
	chat colours) as attributes of the Player. Player data itself only replicates to its
	owner, so nothing else is visible to the others.

		Bounty         number, removed while Settings.Hide_Bounty is on
		LegendaryMode  boolean (Combat.LegendaryMode)
		Rank           "Owner" | "Mod" | nil      (Permissions, or the ModTester flag)
		Tester         "Helper" | "Alpha" | "Beta" | nil   (Spec flags)
		ListHidden     true for the staff of PlayerListConfig.HiddenUserIds

	Already published elsewhere and only read by the clients: HideBounty (SettingsService),
	Top100 (LeaderboardService), CrewName (CrewService).

	Everything is pushed from data observers: no loop, nothing to ask for, no remote.

	The legacy game kept every player's whole data folder in Workspace, so a hidden bounty
	was only hidden by the list script: any client could read it. Here a hidden bounty is
	never sent, and neither is the rank of a moderator who hides it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local RankConfig = require(ReplicatedStorage.Shared.Configs.RankConfig)
local PlayerListConfig = require(ServerStorage.Server.Configs.PlayerListConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local Permissions = require(ServerStorage.Server.Modules.Permissions)

type PlayerData = PlayerData.PlayerData

local ATTRIBUTES = RankConfig.Attributes
local MOD_LEVEL: Permissions.Role = "Mod"
local OWNER_LEVEL: Permissions.Role = "Owner"

local PlayerListService = Knit.CreateService({
	Name = "PlayerListService",
	Client = {},
})

local DataService

-- Attributes replicate on every write: only write what changed.
local function publish(player: Player, attribute: string, value: any)
	if player:GetAttribute(attribute) ~= value then
		player:SetAttribute(attribute, value)
	end
end

local function hidesBounty(data: PlayerData): boolean
	return data:Get("Settings.Hide_Bounty") == true
end

local function publishBounty(player: Player, data: PlayerData)
	local bounty = data:Get("Combat.Bounty")
	local visible = not hidesBounty(data) and type(bounty) == "number"
	publish(player, ATTRIBUTES.Bounty, if visible then bounty else nil)
end

local function publishLegendary(player: Player, data: PlayerData)
	publish(player, ATTRIBUTES.Legendary, data:Get("Combat.LegendaryMode") == true)
end

local function publishRanks(player: Player, data: PlayerData)
	local spec = data:Get("Spec")
	local flags: { [string]: any } = if type(spec) == "table" then spec else {}

	local rank: RankConfig.StaffRank? = nil
	if Permissions.Has(player, OWNER_LEVEL) then
		rank = "Owner"
	elseif (Permissions.Has(player, MOD_LEVEL) or flags.ModTester == true) and not hidesBounty(data) then
		rank = "Mod"
	end

	local tester: RankConfig.TesterRank? = nil
	if flags.HelperTester == true then
		tester = "Helper"
	elseif flags.AlphaTester == true then
		tester = "Alpha"
	elseif flags.BetaTester == true then
		tester = "Beta"
	end

	publish(player, ATTRIBUTES.Rank, rank)
	publish(player, ATTRIBUTES.Tester, tester)
end

local function onData(player: Player, data: PlayerData)
	publishBounty(player, data)
	publishLegendary(player, data)

	data:Observe("Combat.Bounty", function()
		publishBounty(player, data)
	end)
	data:Observe("Combat.LegendaryMode", function()
		publishLegendary(player, data)
	end)
	data:Observe("Settings.Hide_Bounty", function()
		publishBounty(player, data)
		publishRanks(player, data)
	end)
	data:Observe("Spec", function()
		publishRanks(player, data)
	end)

	-- Yields on the group lookup the first time; the observers above are already in place.
	Permissions.Resolve(player)
	if player.Parent == Players and data:IsActive() then
		publishRanks(player, data)
	end
end

local function onPlayer(player: Player)
	if table.find(PlayerListConfig.HiddenUserIds, player.UserId) then
		player:SetAttribute(ATTRIBUTES.Hidden, true)
	end
end

function PlayerListService:KnitInit()
	DataService = Knit.GetService("DataService")
end

function PlayerListService:KnitStart()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	DataService:ObserveData(onData)
end

return PlayerListService
