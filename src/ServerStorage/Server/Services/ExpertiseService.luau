--!strict
--[[
	Expertise: perk points and the Expert's missions.

	Perks
		One point per Expertise level. The client only names the perk; the spent total, the
		cap and the respec price are computed here from saved data.

	Missions
		A mission costs one token at the Expert and runs through Easy -> Medium -> Hard; each
		stage rolls a new requirement from the Expertise level and pays Expertise exp.
		Progress only comes from server events (credited kills, dealt damage, Beri / fish
		gains, ExpertiseService:AddMissionProgress for quest objectives).

	Tokens
		One per real hour up to the saved capacity, granted on load and on the hour by a
		single loop for the whole server.

	Server API
		ExpertiseService.MissionStageCompleted (player, difficulty, objective)
		ExpertiseService:AddMissionProgress(player, objective, amount)
		ExpertiseService:GetPerk(player, perkName) -> number
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local ExpertiseConfig = require(ReplicatedStorage.Shared.Configs.ExpertiseConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

local ExpertiseService = Knit.CreateService({
	Name = "ExpertiseService",
	Client = {
		-- (perkName)
		Invest = Knit.CreateSignal(),
		Respec = Knit.CreateSignal(),
		AcceptMission = Knit.CreateSignal(),
		UpgradeTokens = Knit.CreateSignal(),
		-- server -> client: (difficulty) a mission stage was finished.
		StageCompleted = Knit.CreateSignal(),
	},
})

-- (player, finished difficulty, objective) for challenges and Sam's quest timer.
ExpertiseService.MissionStageCompleted = Signal.new() :: Signal.Signal<Player, string, string>

local DataService
local StatService
local NotifyService
local CombatService
local RewardService

local random = Random.new()

-- Filling a tree is up to 100 clicks in a row; everything else is a deliberate action.
local investLimiter = RateLimiter.new(25, 10)
local actionLimiter = RateLimiter.new(3, 0.5)

local function isRunning(mission: any): boolean
	return mission.Objective ~= "None"
		and mission.Objective ~= ""
		and table.find(ExpertiseConfig.Difficulties, mission.Difficulty) ~= nil
end

local function rollRequirement(data: PlayerData, objective: string, difficulty: string, target: string): number
	local ranges = ExpertiseConfig.GetRanges(objective, target)
	local bounds = ranges and (ranges :: any)[difficulty]
	if not bounds then
		return 1
	end
	local minimum, maximum = ExpertiseConfig.GetRequirementBounds(bounds, data.Data.Skills.Expertise.Level)
	return random:NextInteger(minimum, maximum)
end

local function clearMission(data: PlayerData)
	data:Set("Expertise.Mission.Objective", "None")
	data:Set("Expertise.Mission.ObjectiveTarget", "None")
	data:Set("Expertise.Mission.Difficulty", "None")
	data:Set("Expertise.Mission.Requirement", 0)
	data:Set("Expertise.Mission.Progress", 0)
end

-- Pays and advances every stage the current progress covers; the surplus carries over.
local function resolveStages(player: Player, data: PlayerData)
	local mission = data.Data.Expertise.Mission
	for _ = 1, #ExpertiseConfig.Difficulties do
		if not isRunning(mission) or mission.Requirement <= 0 or mission.Progress < mission.Requirement then
			return
		end

		local difficulty, objective = mission.Difficulty, mission.Objective
		local surplus = math.floor(mission.Progress - mission.Requirement)
		local exp = ExpertiseConfig.StageExp[difficulty :: ExpertiseConfig.Difficulty]
		StatService:AddExp(player, "Expertise", if objective == "Elite Kill" then exp.Elite else exp.Normal, true)

		local nextDifficulty = ExpertiseConfig.GetNextDifficulty(difficulty)
		if nextDifficulty then
			data:Set("Expertise.Mission.Difficulty", nextDifficulty)
			data:Set(
				"Expertise.Mission.Requirement",
				rollRequirement(data, objective, nextDifficulty, mission.ObjectiveTarget)
			)
			data:Set("Expertise.Mission.Progress", math.max(0, surplus))
		else
			clearMission(data)
		end

		ExpertiseService.MissionStageCompleted:Fire(player, difficulty, objective)
		ExpertiseService.Client.StageCompleted:Fire(player, difficulty)
	end
end

local function addProgress(player: Player, data: PlayerData, objective: string, amount: number)
	local mission = data.Data.Expertise.Mission
	if mission.Objective ~= objective or not isRunning(mission) or amount ~= amount or amount <= 0 then
		return
	end
	data:Set("Expertise.Mission.Progress", mission.Progress + math.floor(amount))
	resolveStages(player, data)
end

local function grantTokens(data: PlayerData)
	local hour = math.floor(os.time() / ExpertiseConfig.TokenInterval)
	local lastHour = data.Data.Expertise.Mission.Hour
	if hour == lastHour then
		return
	end

	local tokens = data.Data.ExpertiseTokens
	local earned = math.clamp(hour - lastHour, 0, tokens.Limit)
	data:Set("Expertise.Mission.Hour", hour)
	data:Set("ExpertiseTokens.Current", math.clamp(tokens.Current + earned, 0, tokens.Limit))
end

-- Repairs the saved perk table: missing entries, retired caps, values above the cap.
local function sanitizePerks(data: PlayerData)
	local perks = data.Data.Expertise.Perks
	for name, info in ExpertiseConfig.Perks do
		local perk = perks[name]
		if type(perk) ~= "table" or type(perk.Value) ~= "number" or type(perk.Limit) ~= "number" then
			data:Set(`Expertise.Perks.{name}`, { Value = 0, Limit = info.Limit })
			continue
		end

		local migration = ExpertiseConfig.LimitMigrations[name]
		if migration and perk.Limit == migration.From then
			data:Set(`Expertise.Perks.{name}.Limit`, migration.To)
		end
		if perk.Value > perk.Limit or perk.Value < 0 then
			data:Set(`Expertise.Perks.{name}.Value`, math.clamp(perk.Value, 0, perk.Limit))
		end
	end
end

local function onDataLoaded(player: Player, data: PlayerData)
	sanitizePerks(data)
	grantTokens(data)

	-- Gains only: spending or resetting never moves a mission backwards.
	local function track(path: string, objective: string)
		data:Observe(path, function(value: any, previous: any)
			if type(value) == "number" and type(previous) == "number" and value > previous then
				addProgress(player, data, objective, value - previous)
			end
		end)
	end
	track("Economy.Beri", "Money")
	track("Economy.Fish", "Fish")
	track("Fishing.ChefGift", "SellFish")
end

local function onKillRewarded(killer: Player, victim: CharacterEntity)
	local data = DataService:GetData(killer)
	if not data then
		return
	end

	local mission = data.Data.Expertise.Mission
	if victim.Player then
		addProgress(killer, data, "Player Kill", 1)
	elseif
		(mission.Objective == "Kill" or mission.Objective == "Elite Kill")
		and ExpertiseConfig.MatchesTarget(victim.Model.Name, mission.ObjectiveTarget)
	then
		addProgress(killer, data, mission.Objective, 1)
	end
end

local function onDamaged(context: CombatTypes.DamageContext, dealt: number)
	local attacker, data = context.Attacker, context.AttackerData
	if dealt <= 0 or not attacker or not attacker.Player or not data or attacker == context.Target then
		return
	end
	-- Checked here so a hit without a damage mission costs nothing.
	if data.Data.Expertise.Mission.Objective == "Damage" then
		addProgress(attacker.Player, data, "Damage", dealt)
	end
end

local function invest(player: Player, perkName: unknown)
	if type(perkName) ~= "string" or not ExpertiseConfig.Perks[perkName] or not investLimiter:Consume(player) then
		return
	end

	local data = DataService:GetData(player)
	if not data then
		return
	end

	local perks = data.Data.Expertise.Perks
	local perk = perks[perkName]
	if not perk or perk.Value >= perk.Limit then
		return
	end
	if ExpertiseConfig.GetSpentPoints(perks) >= data.Data.Skills.Expertise.Level then
		return
	end

	data:Set(`Expertise.Perks.{perkName}.Value`, perk.Value + 1)
end

local function respec(player: Player)
	if not actionLimiter:Consume(player) then
		return
	end

	local data = DataService:GetData(player)
	if not data then
		return
	end

	local perks = data.Data.Expertise.Perks
	local spent = ExpertiseConfig.GetSpentPoints(perks)
	if spent <= 0 then
		return
	end
	if not data:TrySpend("Economy.Beri", spent * ExpertiseConfig.RespecCostPerPoint) then
		NotifyService:Send(player, "Not enough Beri", "Error")
		return
	end

	for _, name in ExpertiseConfig.PerkOrder do
		if perks[name] then
			data:Set(`Expertise.Perks.{name}.Value`, 0)
		end
	end
end

local function acceptMission(player: Player)
	if not actionLimiter:Consume(player) then
		return
	end

	local data = DataService:GetData(player)
	if not data or not Proximity.GetMerchant(player, ExpertiseConfig.Merchant) then
		return
	end
	if data.Data.ExpertiseTokens.Current <= 0 then
		NotifyService:Send(player, "No Expertise Tasks available", "Error")
		return
	end
	data:Increment("ExpertiseTokens.Current", -1, 0)

	-- The pool is built per request: the legacy script appended "Elite Kill" to a shared
	-- list every time a Legendary player asked, so it leaked to everyone and kept growing.
	local objectives = table.clone(ExpertiseConfig.Objectives)
	if data.Data.Combat.LegendaryMode then
		table.insert(objectives, ExpertiseConfig.LegendaryObjective)
	end

	local objective = objectives[random:NextInteger(1, #objectives)]
	local target = "None"
	if objective == "Kill" then
		target = ExpertiseConfig.KillTargets[random:NextInteger(1, #ExpertiseConfig.KillTargets)]
	elseif objective == "Elite Kill" then
		target = ExpertiseConfig.EliteKillTargets[random:NextInteger(1, #ExpertiseConfig.EliteKillTargets)]
	end

	-- Taking a new mission replaces the running one, as in the original.
	local difficulty = ExpertiseConfig.Difficulties[1]
	data:Set("Expertise.Mission.Progress", 0)
	data:Set("Expertise.Mission.Requirement", rollRequirement(data, objective, difficulty, target))
	data:Set("Expertise.Mission.ObjectiveTarget", target)
	data:Set("Expertise.Mission.Difficulty", difficulty)
	data:Set("Expertise.Mission.Objective", objective)
end

local function upgradeTokens(player: Player)
	if not actionLimiter:Consume(player) then
		return
	end

	local data = DataService:GetData(player)
	if not data or not Proximity.GetMerchant(player, ExpertiseConfig.Merchant) then
		return
	end

	local limit = data.Data.ExpertiseTokens.Limit
	local cost = ExpertiseConfig.GetTokenUpgradeCost(limit)
	if not cost then
		return
	end
	if not data:TrySpend("Economy.Gems", cost) then
		NotifyService:Send(player, "Not enough Gems", "Error")
		return
	end

	data:Set("ExpertiseTokens.Limit", limit + 1)
	NotifyService:Send(player, "Expertise Task capacity increased", "Success")
end

function ExpertiseService:GetPerk(player: Player, perkName: string): number
	local data = DataService:GetData(player)
	local perk = data and data.Data.Expertise.Perks[perkName]
	return if perk then perk.Value else 0
end

-- For objectives whose source is another system ("Quests": one per finished quest objective).
function ExpertiseService:AddMissionProgress(player: Player, objective: ExpertiseConfig.Objective, amount: number?)
	local data = DataService:GetData(player)
	if data then
		addProgress(player, data, objective, amount or 1)
	end
end

function ExpertiseService:KnitInit()
	DataService = Knit.GetService("DataService")
	StatService = Knit.GetService("StatService")
	NotifyService = Knit.GetService("NotifyService")
	CombatService = Knit.GetService("CombatService")
	RewardService = Knit.GetService("RewardService")
end

function ExpertiseService:KnitStart()
	DataService:ObserveData(onDataLoaded)
	RewardService.KillRewarded:Connect(onKillRewarded)
	CombatService.Damaged:Connect(onDamaged)

	ExpertiseService.Client.Invest:Connect(invest)
	ExpertiseService.Client.Respec:Connect(respec)
	ExpertiseService.Client.AcceptMission:Connect(acceptMission)
	ExpertiseService.Client.UpgradeTokens:Connect(upgradeTokens)

	Players.PlayerRemoving:Connect(function(player: Player)
		investLimiter:Forget(player)
		actionLimiter:Forget(player)
	end)

	-- Wakes once per token interval, right after the hour turns.
	task.spawn(function()
		while true do
			task.wait(ExpertiseConfig.TokenInterval - os.time() % ExpertiseConfig.TokenInterval + 1)
			for _, player in Players:GetPlayers() do
				local data = DataService:GetData(player)
				if data then
					grantTokens(data)
				end
			end
		end
	end)
end

return ExpertiseService
