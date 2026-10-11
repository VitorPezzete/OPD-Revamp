--!strict
--[[
	Server-only odds and payouts of the fruit economy (AffinityMerchant reroll tables,
	fruit drinks, Golden Apple). Clients never see these.

	The legacy game had no timed fruit spawns in the world, so there is no spawn table:
	fruits only reach the ground by being dropped or by their holder dying.
]]

export type Weighted = { Value: number, Weight: number }

local function weights(list: { Weighted }): { Weighted }
	for _, entry in list do
		table.freeze(entry)
	end
	return table.freeze(list)
end

return table.freeze({
	-- Affinity multiplier -> weight. Paying gems doubles every chance above 1.0.
	RerollOdds = table.freeze({
		Beri = weights({
			{ Value = 2, Weight = 0.02 },
			{ Value = 1.9, Weight = 0.08 },
			{ Value = 1.8, Weight = 0.1 },
			{ Value = 1.7, Weight = 0.3 },
			{ Value = 1.6, Weight = 0.5 },
			{ Value = 1.5, Weight = 1 },
			{ Value = 1.4, Weight = 3 },
			{ Value = 1.3, Weight = 5 },
			{ Value = 1.2, Weight = 10 },
			{ Value = 1.1, Weight = 20 },
			{ Value = 1, Weight = 60 },
		}),
		Gems = weights({
			{ Value = 2, Weight = 0.04 },
			{ Value = 1.9, Weight = 0.16 },
			{ Value = 1.8, Weight = 0.2 },
			{ Value = 1.7, Weight = 0.6 },
			{ Value = 1.6, Weight = 1 },
			{ Value = 1.5, Weight = 2 },
			{ Value = 1.4, Weight = 6 },
			{ Value = 1.3, Weight = 10 },
			{ Value = 1.2, Weight = 20 },
			{ Value = 1.1, Weight = 40 },
			{ Value = 1, Weight = 20 },
		}),
	}),

	-- Every fruit drink gives this much experience to each of these skills.
	Drinks = table.freeze({
		Names = table.freeze({
			"Apple Juice",
			"Banana Juice",
			"Pear Juice",
			"Fruit Juice",
			"Pumpkin Juice",
			"Sour Juice",
			"Coconut Milk",
		}),
		Skills = table.freeze({ "Melee", "Sword", "Sniper", "Defense" }),
		MinExp = 45,
		MaxExp = 135,
	}),

	GoldenApple = table.freeze({
		Name = "Golden Apple",
		MinBeri = 5000,
		MaxBeri = 15000,
	}),

	-- Entries kept by the fruit audit log before the oldest are dropped.
	AuditLogSize = 400,
})
