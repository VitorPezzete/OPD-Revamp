--!strict
--[[
	Daily and hourly reward boxes (legacy ClaimRewardDaily / ClaimRewardHourly remotes).
	One box is credited per period the player is seen online in; boxes pile up until opened.
]]

export type Roll = { Value: number, Weight: number }

export type Reward = {
	-- Length of the period, in seconds of the server clock (UTC).
	PeriodSeconds: number,
	-- Player data path the rolled amount is added to.
	Currency: string,
	-- Weights are relative, they do not have to add up to 100 (the legacy daily table adds up to 110).
	Rolls: { Roll },
}

local Rewards: { [string]: Reward } = {
	Daily = {
		PeriodSeconds = 86400,
		Currency = "Economy.Gems",
		Rolls = {
			{ Value = 10, Weight = 45 },
			{ Value = 15, Weight = 35 },
			{ Value = 20, Weight = 20 },
			{ Value = 25, Weight = 10 },
		},
	},
	Hourly = {
		PeriodSeconds = 3600,
		Currency = "Economy.Beri",
		Rolls = {
			{ Value = 10000, Weight = 40 },
			{ Value = 15000, Weight = 30 },
			{ Value = 20000, Weight = 20 },
			{ Value = 25000, Weight = 10 },
		},
	},
}

return table.freeze({
	Rewards = Rewards,
	--[[
		A stored count above this is treated as corrupt and reset. The legacy migrator
		copied the hour stamp (about 490,000) into the pending hourly count, which would
		otherwise pay out half a million boxes.
	]]
	MaxSanePending = 10000,
})
