--!strict
--[[
	Expertise: perk points (one per Expertise level), the Expert's missions and their tokens.

	Perk effects are applied where the stat lives (damage modifiers, CharacterService,
	RewardService, AttackService); this module only describes them and the mission numbers.
]]

export type Difficulty = "Easy" | "Medium" | "Hard"
export type Objective = "Kill" | "Elite Kill" | "Player Kill" | "Damage" | "Quests" | "Money" | "Fish" | "SellFish"

export type PerkInfo = { Limit: number, Description: string }

-- Requirement bounds scale with the Expertise level: bound = round(Base + PerLevel * level).
export type Bound = { Base: number, PerLevel: number }
export type Range = { Min: Bound, Max: Bound }
export type Ranges = { [Difficulty]: Range }

local function range(minBase: number, minPerLevel: number, maxBase: number, maxPerLevel: number): Range
	return table.freeze({
		Min = table.freeze({ Base = minBase, PerLevel = minPerLevel }),
		Max = table.freeze({ Base = maxBase, PerLevel = maxPerLevel }),
	})
end

local function flat(minimum: number, maximum: number): Range
	return range(minimum, 0, maximum, 0)
end

local ExpertiseConfig = {}

-- Display order of the legacy menu.
ExpertiseConfig.PerkOrder = table.freeze({
	"ResistWeapons",
	"ResistAbilities",
	"ResistHaki",
	"ResistGeneral",
	"BuffHealth",
	"BuffRegen",
	"BuffSpeed",
	"BuffWeapons",
	"BuffShave",
	"BuffDash",
	"BuffRewards",
	"AntiHeal",
	"BuffFishing",
	"FullHealth",
	"KillHeal",
	"LowHealth",
	"TargetLow",
	"TrueDamage",
})

-- Limit is the default cap; the cap that counts is the one saved with the player
-- (Expertise.Perks.<Perk>.Limit), which old accounts carry with other values.
ExpertiseConfig.Perks = table.freeze({
	ResistWeapons = { Limit = 20, Description = "Reduces the amount of damage taken from weapons by 2% per level." },
	ResistAbilities = { Limit = 40, Description = "Reduces the amount of damage taken from abilities by 0.5% per level." },
	ResistHaki = { Limit = 40, Description = "Reduces the amount of damage taken from haki by 0.5% per level." },
	ResistGeneral = { Limit = 50, Description = "Increases the user's overall damage resistance by 0.4% per level." },
	BuffHealth = { Limit = 50, Description = "Increases the user's maximum health by 0.4% per level." },
	BuffRegen = { Limit = 40, Description = "Increases the user's health regeneration by 3% per level." },
	BuffSpeed = { Limit = 25, Description = "Increases the user's movement speed by 4% per level." },
	BuffWeapons = { Limit = 50, Description = "Increases the user's weapon damage by 1% per level." },
	BuffShave = { Limit = 25, Description = "Reduces the user's shave cooldown by 0.5% per level." },
	BuffDash = { Limit = 25, Description = "Reduces the user's dash cooldown by 1% per level." },
	BuffRewards = { Limit = 40, Description = "Increases the user's NPC's rewards by 1.25% per level." },
	AntiHeal = { Limit = 50, Description = "Decreases the Target Player's Health Regeneration by 0.6% per level." },
	BuffFishing = { Limit = 50, Description = "Increases the user's Fishing Luck by 2% per level." },
	FullHealth = {
		Limit = 10,
		Description = "Increases damage based on current health, scaling from 0.5% at 60% HP up to 1% at 90% HP per level.",
	},
	KillHeal = { Limit = 10, Description = "After killing a player, heals 2% HP per level." },
	LowHealth = {
		Limit = 10,
		Description = "Increases damage based on current health, scaling from 0.5% at 60% HP up to 1% at 30% HP per level.",
	},
	TargetLow = {
		Limit = 20,
		Description = "Increases the user's damage when Target Player's Health is below 40% by 0.5% per level.",
	},
	TrueDamage = { Limit = 10, Description = "Makes 1% of the user's damage ignore resistances per level." },
} :: { [string]: PerkInfo })

-- Caps changed during the life of the game; saved caps still holding the old value are
-- moved to the new one when the player loads (points above it are refunded).
ExpertiseConfig.LimitMigrations = table.freeze({
	BuffFishing = table.freeze({ From = 25, To = 50 }),
	BuffSpeed = table.freeze({ From = 50, To = 25 }),
	BuffShave = table.freeze({ From = 100, To = 50 }),
} :: { [string]: { From: number, To: number } })

-- Beri per invested point to get every point back.
ExpertiseConfig.RespecCostPerPoint = 2000

ExpertiseConfig.Merchant = "ExpertiseMerchant"

-- One token per real hour, up to the player's capacity. A token buys one mission.
ExpertiseConfig.TokenInterval = 3600
-- Capacity upgrade: capacity * 500 Gems. The merchant stopped offering it at 3 while the
-- old remote accepted up to 5; 3 is what players could reach without firing it by hand.
ExpertiseConfig.TokenLimitMax = 3
ExpertiseConfig.TokenUpgradeGemsPerLimit = 500

ExpertiseConfig.Difficulties = table.freeze({ "Easy", "Medium", "Hard" } :: { Difficulty })

ExpertiseConfig.Objectives = table.freeze({ "Damage", "Money", "Player Kill", "Quests", "Kill", "Fish", "SellFish" } :: { Objective })
-- Extra objective in the pool of Legendary Mode players.
ExpertiseConfig.LegendaryObjective = "Elite Kill" :: Objective

ExpertiseConfig.KillTargets = table.freeze({
	"Freddy",
	"Cave Demon",
	"Crab",
	"Boar",
	"Bandit",
	"Angry Bob",
	"Thug",
	"Thief",
	"Gunslinger",
})
ExpertiseConfig.EliteKillTargets = table.freeze({ "Bruno", "Bucky", "Vokun", "Buster", "Gunner Captain", "Marine" })

-- A "Freddy" mission accepts every spelling the Freddy spawns use.
ExpertiseConfig.TargetAliases = table.freeze({
	Freddy = table.freeze({ "Fred", "Freyd", "Friedrich", "Frued" }),
} :: { [string]: { string } })

ExpertiseConfig.Requirements = table.freeze({
	Kill = table.freeze({
		Easy = range(2, 0.05, 5, 0.1),
		Medium = range(5, 0.15, 10, 0.2),
		Hard = range(30, 0.45, 30, 1),
	}),
	["Player Kill"] = table.freeze({
		Easy = flat(1, 1),
		Medium = range(2, 0.05, 5, 0.05),
		Hard = range(4, 0.2, 7, 0.3),
	}),
	Damage = table.freeze({
		Easy = range(10000, 400, 15000, 500),
		Medium = range(15000, 500, 30000, 1000),
		Hard = range(50000, 1000, 150000, 3000),
	}),
	Quests = table.freeze({
		Easy = flat(1, 1),
		Medium = flat(2, 4),
		Hard = range(5, 0, 7, 0.07),
	}),
	Money = table.freeze({
		Easy = flat(2500, 5500),
		Medium = range(10000, 260, 20000, 1100),
		Hard = range(40000, 2100, 100000, 4000),
	}),
	Fish = table.freeze({
		Easy = flat(1, 2),
		Medium = range(3, 0.05, 5, 0.06),
		Hard = range(7, 0.07, 10, 0.08),
	}),
	SellFish = table.freeze({
		Easy = flat(2500, 5500),
		Medium = range(5000, 50, 10000, 60),
		Hard = range(30000, 500, 50000, 1000),
	}),
	-- Default for elite targets without an entry in EliteRequirements.
	["Elite Kill"] = table.freeze({
		Easy = flat(2, 3),
		Medium = flat(2, 3),
		Hard = flat(3, 4),
	}),
} :: { [Objective]: Ranges })

ExpertiseConfig.EliteRequirements = table.freeze({
	["Gunner Captain"] = table.freeze({ Easy = flat(1, 1), Medium = flat(2, 2), Hard = flat(3, 4) }),
	Marine = table.freeze({ Easy = flat(7, 13), Medium = flat(27, 35), Hard = flat(57, 70) }),
} :: { [string]: Ranges })

-- Expertise exp for finishing a stage (legacy numbers: the first stage is the big one).
ExpertiseConfig.StageExp = table.freeze({
	Easy = table.freeze({ Normal = 100, Elite = 140 }),
	Medium = table.freeze({ Normal = 30, Elite = 50 }),
	Hard = table.freeze({ Normal = 20, Elite = 40 }),
} :: { [Difficulty]: { Normal: number, Elite: number } })

-- Seconds taken off Sam's quest timer by every finished stage (applied by its owner).
ExpertiseConfig.SamQuestBonusSeconds = 300

function ExpertiseConfig.GetRanges(objective: string, target: string): Ranges?
	if objective == "Elite Kill" and ExpertiseConfig.EliteRequirements[target] then
		return ExpertiseConfig.EliteRequirements[target]
	end
	return (ExpertiseConfig.Requirements :: { [string]: Ranges })[objective]
end

-- Inclusive bounds of the requirement roll at an Expertise level.
function ExpertiseConfig.GetRequirementBounds(bounds: Range, level: number): (number, number)
	local minimum = math.round(bounds.Min.Base + bounds.Min.PerLevel * level)
	local maximum = math.round(bounds.Max.Base + bounds.Max.PerLevel * level)
	return minimum, math.max(minimum, maximum)
end

function ExpertiseConfig.GetNextDifficulty(difficulty: string): Difficulty?
	local index = table.find(ExpertiseConfig.Difficulties, difficulty :: any)
	return if index then ExpertiseConfig.Difficulties[index + 1] else nil
end

-- Does an NPC name count for a kill mission on this target?
function ExpertiseConfig.MatchesTarget(npcName: string, target: string): boolean
	if target == "" or target == "None" then
		return false
	end
	if string.find(npcName, target, 1, true) then
		return true
	end
	for _, alias in ExpertiseConfig.TargetAliases[target] or {} do
		if string.find(npcName, alias, 1, true) then
			return true
		end
	end
	return false
end

-- Sum of the invested points of a saved Expertise.Perks table.
function ExpertiseConfig.GetSpentPoints(perks: { [string]: { Value: number, Limit: number } }?): number
	local total = 0
	if perks then
		for _, name in ExpertiseConfig.PerkOrder do
			local perk = perks[name]
			if perk and type(perk.Value) == "number" then
				total += perk.Value
			end
		end
	end
	return total
end

function ExpertiseConfig.GetTokenUpgradeCost(limit: number): number?
	if limit >= ExpertiseConfig.TokenLimitMax then
		return nil
	end
	return limit * ExpertiseConfig.TokenUpgradeGemsPerLimit
end

-- Text of the mission tracker.
function ExpertiseConfig.DescribeMission(objective: string, difficulty: string, target: string, requirement: number): string
	local prefix = `[{difficulty}] `
	if objective == "Kill" then
		return `{prefix}Kill {target} x{requirement}.`
	elseif objective == "Elite Kill" then
		return `{prefix}Elite Kill {target} x{requirement}.`
	elseif objective == "Player Kill" then
		return `{prefix}Kill Players x{requirement}.`
	elseif objective == "Damage" then
		return `{prefix}Deal {requirement} damage.`
	elseif objective == "Quests" then
		return `{prefix}Complete {requirement} quest objectives.`
	elseif objective == "Money" then
		return `{prefix}Earn {requirement} Beris.`
	elseif objective == "Fish" then
		return `{prefix}Catch {requirement} fish.`
	elseif objective == "SellFish" then
		return `{prefix}Sell {requirement} Beris worth of fish.`
	end
	return ""
end

return table.freeze(ExpertiseConfig)
