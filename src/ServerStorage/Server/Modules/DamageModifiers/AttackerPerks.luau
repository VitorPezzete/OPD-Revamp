--!strict
-- Offensive expertise perks of a player attacker.
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local ANTI_HEAL_PER_POINT = 0.006
local ANTI_HEAL_HITS = 10
local TARGET_LOW_THRESHOLD = 0.4
local TARGET_LOW_PER_POINT = 0.005

-- Legacy curve: full perk value in the edge band (>= 90% health, or <= 30% for the low
-- health perk), a reduced value in the middle band, nothing past 60%.
local function healthBandBonus(points: number, ratio: number, fullBand: boolean): number
	local distance = if fullBand then ratio else 1 - ratio
	if distance >= (if fullBand then 0.9 else 0.7) then
		return points * 0.01
	elseif distance >= (if fullBand then 0.6 else 0.4) then
		return (points * 0.5 + (distance * 100 - 60) * (5 / 30)) / 100
	end
	return 0
end

local function apply(context: CombatTypes.DamageContext)
	local attacker, data = context.Attacker, context.AttackerData
	if not attacker or not data then
		return
	end

	local perks = data.Data.Expertise.Perks
	local target = context.Target

	local trueDamage = perks.TrueDamage.Value
	if trueDamage > 0 then
		context.TrueAmount += context.Amount * trueDamage * 0.01
		context.Amount *= 1 - trueDamage * 0.01
	end

	local ratio = attacker:GetHealthRatio()
	if perks.FullHealth.Value > 0 then
		context.Amount *= 1 + healthBandBonus(perks.FullHealth.Value, ratio, true)
	end
	if perks.LowHealth.Value > 0 then
		context.Amount *= 1 + math.max(0, healthBandBonus(perks.LowHealth.Value, ratio, false))
	end

	if perks.TargetLow.Value > 0 and target:GetHealthRatio() <= TARGET_LOW_THRESHOLD then
		context.Amount *= 1 + perks.TargetLow.Value * TARGET_LOW_PER_POINT
	end

	local antiHeal = perks.AntiHeal.Value * ANTI_HEAL_PER_POINT
	if antiHeal > target.AntiHealFraction then
		target.AntiHealFraction = antiHeal
		target.AntiHealHits = ANTI_HEAL_HITS
	end
end

return {
	Name = "AttackerPerks",
	Priority = 100,
	Apply = apply,
} :: CombatTypes.DamageModifier
