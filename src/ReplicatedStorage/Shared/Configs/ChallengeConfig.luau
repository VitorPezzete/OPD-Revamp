--!strict
--[[
	Challenges: daily and weekly tasks, the repeatable general challenges and the
	"Levelling" goals (saved as Challenges.LegendaryUnlock).

	Every task counts one Event. Systems report what happened with
	ChallengeService:Record(player, event, amount?, detail?); which tasks move, their goals
	and their rewards are decided here. The legacy game instead had each system write the
	progress value of "its" challenge by index.

	The legacy Monthly tab was disabled (button and claims commented out) and is not ported.
]]

export type Event =
	"ExpertiseStage" -- an Expertise mission stage finished; detail = its difficulty
	| "BeriEarned" -- amount = Beri gained
	| "Kill" -- any credited kill
	| "PlayerKill"
	| "CompassToken" -- a compass token was spent at Sam
	| "CompassTreasure" -- a compass treasure was dug up; detail = the box found
	| "DailyCompletion" -- the daily 100% reward was claimed
	| "AuraFruitFound" -- an aura fruit came out of a devil fruit box
	| "FruitEaten"
	| "BoatSpend" -- amount = Beri spent on boats
	| "DrinkSpend" -- amount = Beri spent on drinks
	| "AffinityReroll"
	| "ExpDrink" -- an exp drink was used
	| "ChallengeClaimed" -- any daily / weekly / general reward was claimed
	| "FishCaught" -- amount = fish gained
	| "MerlinQuest" -- a Merlin delivery was completed

export type Reward = { Beri: number?, Gems: number?, CompassTokens: number? }

export type Task = {
	Event: Event,
	-- When set, only events reported with this detail count.
	Detail: string?,
	Goal: number,
	Reward: Reward,
	Text: string,
}

export type Period = "Daily" | "Weekly"
export type LevelGoal = "Melee" | "Defense" | "Enemy" | "Extra"

export type LevelStage = {
	Defense: number,
	Melee: number,
	Enemy: string,
	EnemyCount: { number },
	Extra: string,
	ExtraCount: { number },
}

local function entry(event: Event, goal: number, reward: Reward, text: string, detail: string?): Task
	return table.freeze({ Event = event, Detail = detail, Goal = goal, Reward = table.freeze(reward), Text = text })
end

local ChallengeConfig = {}

ChallengeConfig.Periods = table.freeze({ "Daily", "Weekly" } :: { Period })

ChallengeConfig.Daily = table.freeze({
	entry("ExpertiseStage", 1, { Beri = 10000 }, "Complete any Expertise Mission"),
	entry("BeriEarned", 10000, { Beri = 10000 }, "Earn 10,000 Beris"),
	entry("Kill", 30, { Beri = 10000 }, "Get 30 Kills"),
	entry("CompassToken", 1, { Beri = 10000 }, "Claim a Compass Token"),
})

ChallengeConfig.Weekly = table.freeze({
	entry("DailyCompletion", 5, { Beri = 150000 }, "Get 100% Completion for all Daily Tasks"),
	entry("Kill", 1000, { Beri = 150000 }, "Get 1,000 Kills"),
	entry("CompassTreasure", 5, { CompassTokens = 1 }, "Find 5 Compass Treasures"),
})

-- Reward for claiming every task of a period.
ChallengeConfig.Completion = table.freeze({
	Daily = table.freeze({ Gems = 15 }),
	Weekly = table.freeze({ Gems = 50 }),
} :: { [Period]: Reward })

-- Repeatable: claiming resets the progress.
ChallengeConfig.General = table.freeze({
	entry("CompassTreasure", 10, { Beri = 10000 }, "Find a Common Box with a Compass", "Common Box"),
	entry("CompassTreasure", 3, { Beri = 5000 }, "Find an Uncommon Box with a Compass", "Uncommon Box"),
	entry("CompassTreasure", 1, { Beri = 5000 }, "Find a Rare Box with a Compass", "Rare Box"),
	entry("CompassTreasure", 1, { Beri = 10000 }, "Find an Ultra Rare Box with a Compass", "Ultra Rare Box"),
	entry("AuraFruitFound", 1, { Beri = 25000 }, "Find an Aura Fruit in a Devil Fruit Box"),
	entry("ExpertiseStage", 10, { Beri = 10000 }, "Complete Easy Expertise Missions", "Easy"),
	entry("ExpertiseStage", 10, { Beri = 20000 }, "Complete Medium Expertise Missions", "Medium"),
	entry("ExpertiseStage", 10, { Beri = 100000 }, "Complete Hard Expertise Missions", "Hard"),
	entry("FruitEaten", 1, { Beri = 5000 }, "Eat a Devil Fruit"),
	entry("BoatSpend", 100000, { Beri = 5000 }, "Spend Beris on Boats"),
	entry("DrinkSpend", 250000, { Beri = 15000 }, "Spend Beris on Drinks"),
	entry("AffinityReroll", 50, { Beri = 100000 }, "Reroll Devil Fruit Affinities"),
	entry("ExpDrink", 100, { Beri = 5000 }, "Use Exp Drinks"),
	entry("ChallengeClaimed", 100, { Beri = 10000 }, "Complete Challenges"),
})

--[[
	Levelling: four goals per stage (melee level, defense level, kill an enemy type, one
	extra task). Claiming a goal pays GoalBeriPerStage * stage; claiming the whole stage pays
	StageGems and moves to the next one with freshly rolled counts.
]]
ChallengeConfig.LevelGoals = table.freeze({ "Melee", "Defense", "Enemy", "Extra" } :: { LevelGoal })
ChallengeConfig.GoalBeriPerStage = 40000
ChallengeConfig.StageGems = 50

ChallengeConfig.LevelStages = table.freeze({
	{ Defense = 30, Melee = 50, Enemy = "Crab", EnemyCount = { 20, 40 }, Extra = "Compass", ExtraCount = { 1, 1 } },
	{ Defense = 60, Melee = 100, Enemy = "Boar", EnemyCount = { 25, 45 }, Extra = "Quest", ExtraCount = { 1, 5 } },
	{ Defense = 90, Melee = 150, Enemy = "Bandit", EnemyCount = { 30, 50 }, Extra = "Fish", ExtraCount = { 10, 20 } },
	{ Defense = 130, Melee = 200, Enemy = "Angry Bob", EnemyCount = { 40, 65 }, Extra = "Expertise", ExtraCount = { 1, 2 } },
	{ Defense = 175, Melee = 250, Enemy = "Thug", EnemyCount = { 55, 70 }, Extra = "Compass", ExtraCount = { 10, 20 } },
	{ Defense = 225, Melee = 300, Enemy = "Fred", EnemyCount = { 55, 70 }, Extra = "Expertise", ExtraCount = { 3, 5 } },
	{ Defense = 300, Melee = 350, Enemy = "Thief", EnemyCount = { 60, 80 }, Extra = "Compass", ExtraCount = { 5, 10 } },
	{ Defense = 400, Melee = 400, Enemy = "Cave Demon", EnemyCount = { 60, 80 }, Extra = "Expertise", ExtraCount = { 3, 7 } },
	{ Defense = 500, Melee = 500, Enemy = "Vokun", EnemyCount = { 5, 15 }, Extra = "Player", ExtraCount = { 1, 7 } },
} :: { LevelStage })

-- Which event moves each kind of extra goal.
ChallengeConfig.ExtraEvents = table.freeze({
	Compass = "CompassTreasure",
	Quest = "MerlinQuest",
	Fish = "FishCaught",
	Expertise = "ExpertiseStage",
	Player = "PlayerKill",
} :: { [string]: Event })

local EXTRA_TEXT: { [string]: { string } } = {
	Compass = { "Get a Compass", "Get Compasses" },
	Quest = { "Do Merlin Quests", "Do Merlin Quests" },
	Fish = { "Get Fishes", "Get Fishes" },
	Expertise = { "Do a Expertise task", "Do Expertise tasks" },
	Player = { "Kill a Player", "Kill Players" },
}

function ChallengeConfig.GetTasks(period: string): { Task }?
	if period == "Daily" then
		return ChallengeConfig.Daily
	elseif period == "Weekly" then
		return ChallengeConfig.Weekly
	end
	return nil
end

-- Whole days / weeks (Monday based) since the Unix epoch, UTC: what the resets compare.
function ChallengeConfig.GetDayIndex(now: number): number
	return math.floor(now / 86400)
end

function ChallengeConfig.GetWeekIndex(now: number): number
	return math.floor((ChallengeConfig.GetDayIndex(now) + 3) / 7)
end

-- (progress, goal, done) of a daily / weekly task from the saved Challenges table.
function ChallengeConfig.GetPeriodic(challenges: any, period: string, index: number): (number, number, boolean)
	local tasks = ChallengeConfig.GetTasks(period)
	local definition = tasks and tasks[index]
	if not definition then
		return 0, 1, false
	end
	local saved = type(challenges) == "table" and type(challenges[period]) == "table" and challenges[period][tostring(index)]
	if type(saved) ~= "table" then
		return 0, definition.Goal, false
	end
	return math.min(tonumber(saved.P) or 0, definition.Goal), definition.Goal, saved.Done == true
end

-- (claimed tasks, total tasks, completion already claimed)
function ChallengeConfig.GetCompletion(challenges: any, period: string): (number, number, boolean)
	local tasks = ChallengeConfig.GetTasks(period) or {}
	local claimed = 0
	for index in tasks do
		local _, _, done = ChallengeConfig.GetPeriodic(challenges, period, index)
		if done then
			claimed += 1
		end
	end
	local all = type(challenges) == "table" and type(challenges.AllCompleted) == "table" and challenges.AllCompleted[period]
	return claimed, #tasks, all == true
end

-- (progress, goal) of a general challenge. Saved as Challenges.General["<index>"] = number.
function ChallengeConfig.GetGeneral(challenges: any, index: number): (number, number)
	local definition = ChallengeConfig.General[index]
	if not definition then
		return 0, 1
	end
	local saved = type(challenges) == "table" and type(challenges.General) == "table" and challenges.General[tostring(index)]
	return math.min(if type(saved) == "number" then saved else 0, definition.Goal), definition.Goal
end

-- (progress, goal, done) of a levelling goal. meleeLevel / defenseLevel are the player's skills.
function ChallengeConfig.GetLevelGoal(challenges: any, goal: string, meleeLevel: number, defenseLevel: number): (number, number, boolean)
	local unlock = type(challenges) == "table" and challenges.LegendaryUnlock
	if type(unlock) ~= "table" then
		return 0, 1, false
	end

	if goal == "Melee" or goal == "Defense" then
		local saved = unlock[goal .. "Lvl"]
		if type(saved) ~= "table" then
			return 0, 1, false
		end
		local target = math.max(1, tonumber(saved.Goal) or 1)
		local level = if goal == "Melee" then meleeLevel else defenseLevel
		return math.min(level, target), target, saved.Completed == true
	end

	local saved = unlock[goal]
	if type(saved) ~= "table" then
		return 0, 1, false
	end
	local target = math.max(1, tonumber(saved.Limit) or 1)
	return math.min(tonumber(saved.Progress) or 0, target), target, saved.Completed == true
end

-- (claimed goals, total goals, every stage finished)
function ChallengeConfig.GetLevelCompletion(challenges: any): (number, number, boolean)
	local claimed = 0
	for _, goal in ChallengeConfig.LevelGoals do
		local _, _, done = ChallengeConfig.GetLevelGoal(challenges, goal, 0, 0)
		if done then
			claimed += 1
		end
	end
	local unlock = type(challenges) == "table" and challenges.LegendaryUnlock
	return claimed, #ChallengeConfig.LevelGoals, type(unlock) == "table" and unlock.AllDone == true
end

function ChallengeConfig.GetStage(challenges: any): number
	local unlock = type(challenges) == "table" and challenges.LegendaryUnlock
	local stage = type(unlock) == "table" and tonumber(unlock.TotalLevel) or 1
	return math.clamp(stage, 1, #ChallengeConfig.LevelStages)
end

function ChallengeConfig.DescribeLevelGoal(challenges: any, goal: string): string
	local unlock = type(challenges) == "table" and challenges.LegendaryUnlock
	if goal == "Melee" then
		return "Get Melee Level"
	elseif goal == "Defense" then
		return "Get Defense Level"
	elseif type(unlock) ~= "table" or type(unlock[goal]) ~= "table" then
		return ""
	elseif goal == "Enemy" then
		return `Kill {unlock.Enemy.Name}`
	end
	local texts = EXTRA_TEXT[unlock.Extra.Name]
	if not texts then
		return ""
	end
	return if (tonumber(unlock.Extra.Limit) or 1) > 1 then texts[2] else texts[1]
end

-- Rewards waiting to be claimed: the number on the menu button.
function ChallengeConfig.CountClaimable(challenges: any, meleeLevel: number, defenseLevel: number): number
	local count = 0

	for _, period in ChallengeConfig.Periods do
		for index in ChallengeConfig.GetTasks(period) :: { Task } do
			local progress, goal, done = ChallengeConfig.GetPeriodic(challenges, period, index)
			if not done and progress >= goal then
				count += 1
			end
		end
		local claimed, total, all = ChallengeConfig.GetCompletion(challenges, period)
		if not all and claimed >= total then
			count += 1
		end
	end

	for index in ChallengeConfig.General do
		local progress, goal = ChallengeConfig.GetGeneral(challenges, index)
		if progress >= goal then
			count += 1
		end
	end

	for _, goal in ChallengeConfig.LevelGoals do
		local progress, target, done = ChallengeConfig.GetLevelGoal(challenges, goal, meleeLevel, defenseLevel)
		if not done and progress >= target then
			count += 1
		end
	end

	return count
end

return table.freeze(ChallengeConfig)
