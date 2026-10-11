--!strict
--[[
	Challenges: daily / weekly tasks, repeatable general challenges and the levelling goals.

	Progress
		ChallengeService:Record(player, event, amount?, detail?) moves every task that counts
		that event (ChallengeConfig). The service feeds itself from the signals of the other
		services (kills, Beri and fish gains, compass tokens spent, fruits eaten, Expertise
		stages, shop purchases, drinks, affinity rerolls); events without a signal yet are
		reported by their systems, see ChallengeConfig.Event.

	Resets
		Daily tasks reset when the UTC day changes, weekly ones when the week (Monday) does.
		Checked on load, before a claim, and once a minute by a single loop for the server.

	Claims
		The client names a section and an index. Goals, completion and rewards are read from
		saved data and the config; nothing else is taken from the request.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local ChallengeConfig = require(ReplicatedStorage.Shared.Configs.ChallengeConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

local ChallengeService = Knit.CreateService({
	Name = "ChallengeService",
	Client = {
		-- (section: "Daily" | "Weekly" | "General" | "Level", index: number | "All")
		Claim = Knit.CreateSignal(),
	},
})

local DataService
local RewardService
local ExpertiseService
local FruitService
local ShopService
local ConsumableService
local AffinityService

local RESET_CHECK_INTERVAL = 60
local COMPLETION = "All"

local random = Random.new()
local claimLimiter = RateLimiter.new(6, 2)
local currentDay = ChallengeConfig.GetDayIndex(os.time())

local function grant(data: PlayerData, reward: ChallengeConfig.Reward, multiplier: number?)
	local scale = multiplier or 1
	if reward.Beri then
		data:Increment("Economy.Beri", reward.Beri * scale)
	end
	if reward.Gems then
		data:Increment("Economy.Gems", reward.Gems * scale)
	end
	if reward.CompassTokens then
		data:Increment("CompassTokens.Current", reward.CompassTokens * scale)
	end
end

local function resetPeriod(data: PlayerData, period: ChallengeConfig.Period)
	local fresh = {}
	for index in ChallengeConfig.GetTasks(period) :: { ChallengeConfig.Task } do
		fresh[tostring(index)] = { P = 0, Done = false }
	end
	data:Set(`Challenges.{period}`, fresh)
	data:Set(`Challenges.AllCompleted.{period}`, false)
end

local function refreshPeriods(data: PlayerData)
	local now = os.time()
	local stamps = data.Data.Challenges.Timestamps

	local day = tostring(ChallengeConfig.GetDayIndex(now))
	if stamps.DayOfYear ~= day then
		data:Set("Challenges.Timestamps.DayOfYear", day)
		resetPeriod(data, "Daily")
	end

	local week = tostring(ChallengeConfig.GetWeekIndex(now))
	if stamps.WeekOfYear ~= week then
		data:Set("Challenges.Timestamps.WeekOfYear", week)
		resetPeriod(data, "Weekly")
	end
end

local function counts(task: ChallengeConfig.Task, event: string, detail: string?): boolean
	return task.Event == event and (task.Detail == nil or task.Detail == detail)
end

local function record(data: PlayerData, event: ChallengeConfig.Event, amount: number, detail: string?)
	if amount ~= amount or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	local challenges = data.Data.Challenges

	for _, period in ChallengeConfig.Periods do
		for index, task in ChallengeConfig.GetTasks(period) :: { ChallengeConfig.Task } do
			if counts(task, event, detail) then
				local progress, goal = ChallengeConfig.GetPeriodic(challenges, period, index)
				if progress < goal then
					data:Set(`Challenges.{period}.{index}.P`, math.min(goal, progress + amount))
				end
			end
		end
	end

	for index, task in ChallengeConfig.General do
		if counts(task, event, detail) then
			local progress, goal = ChallengeConfig.GetGeneral(challenges, index)
			if progress < goal then
				data:Set(`Challenges.General.{index}`, math.min(goal, progress + amount))
			end
		end
	end

	local extra = challenges.LegendaryUnlock.Extra
	if ChallengeConfig.ExtraEvents[extra.Name] == event and extra.Progress < extra.Limit then
		data:Set("Challenges.LegendaryUnlock.Extra.Progress", math.min(extra.Limit, extra.Progress + amount))
	end
end

local function onClaimed(data: PlayerData)
	data:Increment("Challenges.Total", 1)
	record(data, "ChallengeClaimed", 1)
end

local function claimPeriodic(data: PlayerData, period: ChallengeConfig.Period, index: unknown)
	refreshPeriods(data)
	local challenges = data.Data.Challenges

	if index == COMPLETION then
		local claimed, total, all = ChallengeConfig.GetCompletion(challenges, period)
		if all or claimed < total then
			return
		end
		data:Set(`Challenges.AllCompleted.{period}`, true)
		grant(data, ChallengeConfig.Completion[period])
		if period == "Daily" then
			record(data, "DailyCompletion", 1)
		end
		return
	end

	local tasks = ChallengeConfig.GetTasks(period) :: { ChallengeConfig.Task }
	local task = type(index) == "number" and tasks[index]
	if not task then
		return
	end
	local progress, goal, done = ChallengeConfig.GetPeriodic(challenges, period, index :: number)
	if done or progress < goal then
		return
	end

	data:Set(`Challenges.{period}.{index :: number}.Done`, true)
	grant(data, task.Reward)
	onClaimed(data)
end

local function claimGeneral(data: PlayerData, index: unknown)
	local task = type(index) == "number" and ChallengeConfig.General[index]
	if not task then
		return
	end
	local progress, goal = ChallengeConfig.GetGeneral(data.Data.Challenges, index :: number)
	if progress < goal then
		return
	end

	data:Set(`Challenges.General.{index :: number}`, 0)
	grant(data, task.Reward)
	onClaimed(data)
end

local function rollCount(bounds: { number }): number
	return random:NextInteger(bounds[1], bounds[2])
end

local function claimLevel(data: PlayerData, index: unknown)
	local challenges = data.Data.Challenges
	local unlock = challenges.LegendaryUnlock
	local stage = ChallengeConfig.GetStage(challenges)

	if index == COMPLETION then
		local claimed, total, allDone = ChallengeConfig.GetLevelCompletion(challenges)
		if allDone or claimed < total then
			return
		end

		local nextStage = ChallengeConfig.LevelStages[stage + 1]
		if not nextStage then
			-- The last stage only closes the track (the legacy game paid nothing for it either).
			data:Set("Challenges.LegendaryUnlock.AllDone", true)
			return
		end

		data:Set("Challenges.LegendaryUnlock", {
			TotalLevel = stage + 1,
			AllDone = false,
			DefenseLvl = { Goal = nextStage.Defense, Completed = false },
			MeleeLvl = { Goal = nextStage.Melee, Completed = false },
			Enemy = { Name = nextStage.Enemy, Progress = 0, Limit = rollCount(nextStage.EnemyCount), Completed = false },
			Extra = { Name = nextStage.Extra, Progress = 0, Limit = rollCount(nextStage.ExtraCount), Completed = false },
		})
		data:Increment("Economy.Gems", ChallengeConfig.StageGems)
		return
	end

	local goal = type(index) == "number" and ChallengeConfig.LevelGoals[index]
	if not goal or unlock.AllDone then
		return
	end
	local skills = data.Data.Skills
	local progress, target, done = ChallengeConfig.GetLevelGoal(challenges, goal, skills.Melee.Level, skills.Defense.Level)
	if done or progress < target then
		return
	end

	local key = if goal == "Melee" or goal == "Defense" then goal .. "Lvl" else goal
	data:Set(`Challenges.LegendaryUnlock.{key}.Completed`, true)
	data:Increment("Economy.Beri", ChallengeConfig.GoalBeriPerStage * stage)
end

local function claim(player: Player, section: unknown, index: unknown)
	if not claimLimiter:Consume(player) then
		return
	end
	-- Integers only: the index ends up in a data path.
	if index ~= COMPLETION and (type(index) ~= "number" or index % 1 ~= 0) then
		return
	end

	local data = DataService:GetData(player)
	if not data then
		return
	end

	if section == "Daily" or section == "Weekly" then
		claimPeriodic(data, section, index)
	elseif section == "General" then
		claimGeneral(data, index)
	elseif section == "Level" then
		claimLevel(data, index)
	end
end

local function onDataLoaded(_player: Player, data: PlayerData)
	refreshPeriods(data)

	local function gained(path: string, event: ChallengeConfig.Event)
		data:Observe(path, function(value: any, previous: any)
			if type(value) == "number" and type(previous) == "number" and value > previous then
				record(data, event, value - previous)
			end
		end)
	end
	gained("Economy.Beri", "BeriEarned")
	gained("Economy.Fish", "FishCaught")

	data:Observe("CompassTokens.Current", function(value: any, previous: any)
		if type(value) == "number" and type(previous) == "number" and value < previous then
			record(data, "CompassToken", 1)
		end
	end)
end

local function onKillRewarded(killer: Player, victim: CharacterEntity)
	local data = DataService:GetData(killer)
	if not data then
		return
	end

	record(data, "Kill", 1)
	if victim.Player then
		record(data, "PlayerKill", 1)
		return
	end

	local enemy = data.Data.Challenges.LegendaryUnlock.Enemy
	if enemy.Progress < enemy.Limit and string.find(victim.Model.Name, enemy.Name, 1, true) then
		data:Set("Challenges.LegendaryUnlock.Enemy.Progress", enemy.Progress + 1)
	end
end

-- Reports something a challenge may count. Unknown or uncounted events are ignored.
function ChallengeService:Record(player: Player, event: ChallengeConfig.Event, amount: number?, detail: string?)
	local data = DataService:GetData(player)
	if data then
		record(data, event, amount or 1, detail)
	end
end

function ChallengeService:KnitInit()
	DataService = Knit.GetService("DataService")
	RewardService = Knit.GetService("RewardService")
	ExpertiseService = Knit.GetService("ExpertiseService")
	FruitService = Knit.GetService("FruitService")
	ShopService = Knit.GetService("ShopService")
	ConsumableService = Knit.GetService("ConsumableService")
	AffinityService = Knit.GetService("AffinityService")
end

function ChallengeService:KnitStart()
	DataService:ObserveData(onDataLoaded)
	RewardService.KillRewarded:Connect(onKillRewarded)

	ExpertiseService.MissionStageCompleted:Connect(function(player: Player, difficulty: string)
		ChallengeService:Record(player, "ExpertiseStage", 1, difficulty)
	end)
	-- Not FruitChanged: that one also fires for a bound fruit coming back and for slot swaps.
	FruitService.FruitEaten:Connect(function(player: Player)
		ChallengeService:Record(player, "FruitEaten", 1)
	end)

	ShopService.Purchased:Connect(function(player: Player, _merchantName: string, item: any)
		if item.Grant == "Boat" then
			ChallengeService:Record(player, "BoatSpend", item.Price)
		elseif item.Grant == "Consumable" then
			ChallengeService:Record(player, "DrinkSpend", item.Price)
		end
	end)
	ConsumableService.Consumed:Connect(function(player: Player)
		ChallengeService:Record(player, "ExpDrink", 1)
	end)
	Knit.GetService("JuiceService").Drank:Connect(function(player: Player)
		ChallengeService:Record(player, "ExpDrink", 1)
	end)
	AffinityService.Rerolled:Connect(function(player: Player)
		ChallengeService:Record(player, "AffinityReroll", 1)
	end)

	ChallengeService.Client.Claim:Connect(claim)
	Players.PlayerRemoving:Connect(function(player: Player)
		claimLimiter:Forget(player)
	end)

	task.spawn(function()
		while true do
			task.wait(RESET_CHECK_INTERVAL)
			local day = ChallengeConfig.GetDayIndex(os.time())
			if day ~= currentDay then
				currentDay = day
				for _, player in Players:GetPlayers() do
					local data = DataService:GetData(player)
					if data then
						refreshPeriods(data)
					end
				end
			end
		end
	end)
end

return ChallengeService
