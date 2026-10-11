--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)

export type Levels = {
	Melee: number,
	Defense: number,
	Sniper: number,
	Sword: number,
	Haki: number,
	Special: number?,
}

local StatConfig = {}

StatConfig.Caps = table.freeze({
	Melee = 500,
	Defense = 500,
	Sniper = 500,
	Sword = 500,
	Haki = 1000,
	Expertise = 100,
} :: { [DataTypes.SkillName]: number })

StatConfig.BasePlayerHealth = 100
StatConfig.BaseWalkSpeed = 16
-- Fraction of base walk speed added per BuffSpeed point.
StatConfig.SpeedPerPerkPoint = 0.04
-- Haki level needed to toggle armament haki.
StatConfig.HakiRequirement = 200
-- Observation is the first haki: available as soon as the Haki skill is unlocked (level 1).
StatConfig.ObservationRequirement = 1

-- Fraction of max health restored per second, and the extra fraction per BuffRegen point.
StatConfig.BaseRegen = 0.01020408163265306
StatConfig.RegenPerPerkPoint = 0.00029573

-- Fraction of max health added per BuffHealth point.
StatConfig.HealthPerPerkPoint = 0.004

-- Exp needed to leave `level`. Expertise has its own, steeper curve.
function StatConfig.GetExpRequirement(skill: DataTypes.SkillName, level: number): number
	if skill == "Expertise" then
		return math.ceil(0.2 * level ^ 2.2 + level + 100)
	end
	return 100 + level * 10
end

function StatConfig.GetHealthFromLevels(levels: Levels): number
	return levels.Defense * 16 + levels.Melee * 3.8 + levels.Haki * 20
end

-- Sum used for bounty/reward scaling.
function StatConfig.GetTotalLevel(levels: Levels): number
	return levels.Defense + levels.Sniper + levels.Sword + levels.Melee + levels.Haki + (levels.Special or 0)
end

return table.freeze(StatConfig)
