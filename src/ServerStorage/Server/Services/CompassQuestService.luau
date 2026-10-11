--!strict
--[[
	Sam's compass tokens (QuestMerchant) and the friend's strange compasses
	(FriendMerchant): earning tokens over time and trading them for compass tools.
	Buying token capacity is CompassTokenService; buying tokens with Robux belongs to
	the purchases system.

	Public servers: one token every 30 minutes (less on weekends, and 3 seconds less
	per Expertise level) while below the limit. The time of the next token is published as
	a player attribute so the client can count down by itself. The legacy game ran one
	loop per player ticking a value every second; here each player has a single
	scheduled grant.

	Private servers: no tokens are earned. The owner trades bought VIP tokens for
	compasses (every 50 add a Golden Compass) and aura tokens for strange compasses.
	Whether the server is private and who owns it is PrivateServerService's answer, never
	game.PrivateServerOwnerId: that one is 0 in a code server, and the answer can change
	while the server runs (a reserved server learns its code from its first arrival, a
	developer simulates a private server).

	Fixed from the legacy remotes: claims could be fired from anywhere (players further
	than 6000 studs got a fake compass and a webhook; closer ones were served), before
	data had loaded, and while dead.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local TOKENS = FruitEconomyConfig.Tokens
local MERCHANT_RANGE = 35
local ITEM_FOLDER = "Items"

local CompassQuestService = Knit.CreateService({
	Name = "CompassQuestService",
	Client = {},
})

local DataService
local CharacterService
local NotifyService
local PrivateServerService
local QuestService
local WebhookService
local WorldEventService

local claimLimiter = RateLimiter.new(3, 1)

-- os.clock() of each player's next token, and the thread that will grant it.
local readyAt: { [Player]: number } = {}
local pending: { [Player]: thread } = {}

local schedule: (player: Player, data: any) -> ()

local function cancel(player: Player)
	local thread = pending[player]
	if thread then
		pending[player] = nil
		task.cancel(thread)
	end
	readyAt[player] = nil
end

local function arm(player: Player, data: any, seconds: number)
	local thread = pending[player]
	if thread then
		task.cancel(thread)
	end

	readyAt[player] = os.clock() + seconds
	player:SetAttribute(TOKENS.ReadyAttribute, Workspace:GetServerTimeNow() + seconds)
	pending[player] = task.delay(seconds, function()
		pending[player] = nil
		readyAt[player] = nil
		if player.Parent ~= Players or DataService:GetData(player) ~= data then
			return
		end

		local tokens = data.Data.CompassTokens
		if tokens.Current < tokens.Limit then
			-- The change wakes the observer below, which schedules the next token.
			data:Increment("CompassTokens.Current", 1)
		else
			player:SetAttribute(TOKENS.ReadyAttribute, nil)
		end
	end)
end

function schedule(player: Player, data: any)
	-- No token is earned in a private server.
	if pending[player] or PrivateServerService:IsPrivate() then
		return
	end

	local tokens = data.Data.CompassTokens
	if tokens.Current >= tokens.Limit then
		player:SetAttribute(TOKENS.ReadyAttribute, nil)
		return
	end

	local base = TOKENS.Seconds * WorldEventService:GetMultiplier("CompassTokenTime")
	local expertise = data.Data.Skills.Expertise.Level
	arm(player, data, math.max(0, base - TOKENS.SecondsPerExpertiseLevel * expertise))
end

-- Brings the next token closer (fishing rewards). No effect while the tokens are full.
function CompassQuestService:ReduceTimer(player: Player, seconds: number)
	local data = DataService:GetData(player)
	local ready = readyAt[player]
	if not data or not ready or seconds ~= seconds or seconds <= 0 then
		return
	end
	arm(player, data, math.max(0, ready - os.clock() - seconds))
end

local function hasItem(name: string): boolean
	return ToolTemplates.Find(name, ITEM_FOLDER) ~= nil
end

local function give(player: Player, name: string, amount: number)
	for _ = 1, amount do
		ToolTemplates.Give(player, name, ITEM_FOLDER)
	end
end

local function getClaimAmount(amount: unknown): number?
	return if type(amount) == "number" and table.find(TOKENS.ClaimAmounts, amount) then amount else nil
end

-- A living, spawned character with loaded data, standing at one of the merchants.
local function getCustomer(player: Player, merchants: { string }): any
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not data:IsActive() or not entity or entity.Dead or not entity.Spawned then
		return nil
	end
	if not claimLimiter:Consume(player) then
		return nil
	end
	for _, merchantName in merchants do
		if Proximity.GetMerchant(player, merchantName, MERCHANT_RANGE) then
			return data
		end
	end
	-- The legacy remote reported claims fired from across the map.
	WebhookService:Flag(player, "CompassClaimFar")
	return nil
end

-- Counts claimed compasses towards a bonus compass. Returns how many bonuses were earned.
local function addRush(data: any, path: string, claimed: number, goal: number): number
	local total = data:Get(path) + claimed
	local bonus = total // goal
	data:Set(path, total - bonus * goal)
	return bonus
end

-- Trades up to `amount` (1 or 10) tokens for compasses. Returns how many were given.
function CompassQuestService.Client:Claim(player: Player, amount: unknown): number
	local wanted = getClaimAmount(amount)
	local data = wanted and getCustomer(player, TOKENS.QuestMerchants)
	if not wanted or not data or not hasItem(TOKENS.CompassItem) then
		return 0
	end

	if not PrivateServerService:IsPrivate() then
		local claimed = math.min(wanted, data.Data.CompassTokens.Current)
		if claimed <= 0 then
			return 0
		end
		data:Increment("CompassTokens.Current", -claimed)
		give(player, TOKENS.CompassItem, claimed)
		return claimed
	end

	if not PrivateServerService:IsOwner(player) then
		NotifyService:Send(player, "Only the private server owner can claim VIP tokens", "Error")
		return 0
	end

	local claimed = math.min(wanted, data.Data.CompassTokens.VIPBonus)
	if claimed <= 0 then
		return 0
	end
	data:Increment("CompassTokens.VIPBonus", -claimed)
	give(player, TOKENS.CompassItem, claimed)

	local bonus = addRush(data, "Shop.VIPRush", claimed, TOKENS.VIPRushGoal)
	if bonus > 0 then
		give(player, TOKENS.GoldenCompassItem, bonus)
	end
	return claimed
end

-- Private server owners: trades aura tokens for strange compasses at FriendMerchant.
function CompassQuestService.Client:ClaimAura(player: Player, amount: unknown): number
	local wanted = getClaimAmount(amount)
	if not wanted then
		return 0
	end
	if not PrivateServerService:IsOwner(player) then
		NotifyService:Send(player, "Only the private server owner can claim strange compasses", "Error")
		return 0
	end

	local data = getCustomer(player, { TOKENS.AuraMerchant })
	if not data or not hasItem(TOKENS.StrangeCompassItem) then
		return 0
	end

	local claimed = math.min(wanted, data.Data.CompassTokens.AuraBonus)
	if claimed <= 0 then
		return 0
	end
	data:Increment("CompassTokens.AuraBonus", -claimed)
	give(player, TOKENS.StrangeCompassItem, claimed)

	local bonus = addRush(data, "Shop.AuraCompass", claimed, FruitEconomyConfig.GetAuraRushGoal())
	if bonus > 0 then
		give(player, TOKENS.GoldenStrangeCompassItem, bonus)
	end
	return claimed
end

function CompassQuestService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
	-- Loaded wherever this service is: both only exist in the places that load everything.
	PrivateServerService = Knit.GetService("PrivateServerService")
	QuestService = Knit.GetService("QuestService")
	WebhookService = Knit.GetService("WebhookService")
	WorldEventService = Knit.GetService("WorldEventService")
end

function CompassQuestService:KnitStart()
	-- Connected before any token is scheduled: whichever of the two services starts first,
	-- a wait armed while the server was still thought public is taken back here.
	PrivateServerService.Changed:Connect(function(isPrivate: boolean)
		for _, player in Players:GetPlayers() do
			if isPrivate then
				cancel(player)
				player:SetAttribute(TOKENS.ReadyAttribute, nil)
			else
				-- Back to public (a simulation ended): the wait starts over.
				local data = DataService:GetData(player)
				if data then
					schedule(player, data)
				end
			end
		end
	end)

	DataService:ObserveData(function(player: Player, data: any)
		-- Spending a token or raising the limit restarts the wait; a running one is kept.
		data:Observe("CompassTokens", function()
			if player.Parent == Players and DataService:GetData(player) == data then
				schedule(player, data)
			end
		end)
		schedule(player, data)
	end)

	-- Fishing and expertise rewards shorten the wait through the quest system.
	QuestService.SamTimerReduced:Connect(function(player: Player, seconds: number)
		CompassQuestService:ReduceTimer(player, seconds)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		claimLimiter:Forget(player)
		cancel(player)
	end)
end

return CompassQuestService
