--!strict
--[[
	Daily and hourly reward boxes.

		DailyRewardService.Client:Claim("Daily" | "Hourly") -> number?   (amount paid, nil if refused)
		DailyRewardService.Claimed (player, kind, amount)

	Data: Rewards.<Kind>.N is the number of unopened boxes, Rewards.<Kind>.R the index of the
	last period (hours or days since the epoch, UTC) a box was credited for. The legacy data
	kept that index in a separate value and used R as a write-only counter; R is reused so
	the schema does not grow.

	Only the server clock is involved: the client sends the kind of box and nothing else.
	The legacy game ran two loops over every player (one of them every frame) to notice a
	new hour or day; here a single timer sleeps until the next hour boundary (a day boundary
	is also an hour boundary) and joins are handled when the data loads.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local DailyRewardConfig = require(ServerStorage.Server.Configs.DailyRewardConfig)

type PlayerData = PlayerData.PlayerData

local DailyRewardService = Knit.CreateService({
	Name = "DailyRewardService",
	Client = {},
})

DailyRewardService.Claimed = Signal.new() :: Signal.Signal<Player, string, number>

local HOUR = 3600

local DataService

local random = Random.new()
-- The opening animation takes about five seconds per box on the client.
local limiter = RateLimiter.new(4, 1)

local function getPending(data: PlayerData, kind: string): number
	local pending = data:Get(`Rewards.{kind}.N`)
	if type(pending) ~= "number" or pending ~= pending or pending < 0 then
		return 0
	end
	return math.floor(pending)
end

-- Adds one box for every reward whose current period the player has not been credited for.
local function credit(data: PlayerData, now: number)
	for kind, reward in DailyRewardConfig.Rewards do
		local stored = data:Get(`Rewards.{kind}.N`)
		local pending = getPending(data, kind)
		if pending > DailyRewardConfig.MaxSanePending then
			pending = 0
		end

		local period = now // reward.PeriodSeconds
		if data:Get(`Rewards.{kind}.R`) ~= period then
			data:Set(`Rewards.{kind}.R`, period)
			pending += 1
		end
		if pending ~= stored then
			data:Set(`Rewards.{kind}.N`, pending)
		end
	end
end

local function roll(reward: DailyRewardConfig.Reward): number
	local total = 0
	for _, entry in reward.Rolls do
		total += entry.Weight
	end

	local pick = random:NextNumber(0, total)
	local accumulated = 0
	for _, entry in reward.Rolls do
		accumulated += entry.Weight
		if pick <= accumulated then
			return entry.Value
		end
	end
	return reward.Rolls[#reward.Rolls].Value
end

function DailyRewardService.Client:Claim(player: Player, kind: unknown): number?
	if not limiter:Consume(player) then
		return nil
	end
	if type(kind) ~= "string" then
		return nil
	end

	local reward = DailyRewardConfig.Rewards[kind]
	local data: PlayerData? = DataService:GetData(player)
	if not reward or not data or not data:IsActive() then
		return nil
	end

	local pending = getPending(data, kind)
	if pending < 1 or pending > DailyRewardConfig.MaxSanePending then
		return nil
	end

	-- The box is taken before the payout; nothing yields in between.
	data:Set(`Rewards.{kind}.N`, pending - 1)
	local amount = roll(reward)
	data:Increment(reward.Currency, amount)

	DailyRewardService.Claimed:Fire(player, kind, amount)
	return amount
end

function DailyRewardService:KnitInit()
	DataService = Knit.GetService("DataService")
end

function DailyRewardService:KnitStart()
	DataService:ObserveData(function(_player: Player, data: PlayerData)
		credit(data, os.time())
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
	end)

	task.spawn(function()
		while true do
			-- One second past the boundary, so the period index has certainly changed.
			task.wait(HOUR - os.time() % HOUR + 1)

			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data then
					credit(data, now)
				end
			end
		end
	end)
end

return DailyRewardService
