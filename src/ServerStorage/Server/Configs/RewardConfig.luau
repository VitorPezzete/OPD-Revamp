--!strict
return table.freeze({
	-- Killing these accounts (staff) never pays out.
	NoRewardUserIds = table.freeze({ 451082957, 571687119, 106625686, 630398541, 3581002119, 656022601, 7124931877 }),

	-- Bounty multipliers of a player victim; they stack multiplicatively.
	FruitMultiplier = 1.5,
	LegendaryMultiplier = 1.5,

	-- NPC payout: total level plus a random bonus in [variation / 2, variation].
	NpcVariationFraction = 0.5,
	NpcVariationMin = 6,
	NpcVariationMax = 3000,
	NpcVariationScale = 1.5,

	-- Extra NPC payout per BuffRewards perk point.
	RewardsPerPerkPoint = 0.0125,
	-- Fraction of max health restored per KillHeal perk point on a player kill.
	KillHealPerPerkPoint = 0.02,

	-- Luck fruit: chance of an extra Beri payout worth this many times the reward.
	LuckFruitName = "Luck",
	LuckChance = 0.2,
	LuckBonusMultiplier = 4,
})
