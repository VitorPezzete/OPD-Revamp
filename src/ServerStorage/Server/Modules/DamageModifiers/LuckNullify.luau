--!strict
--[[
	Luck fruit passive: every hit against a player who has eaten the Luck fruit (either
	slot) has a 15% chance of dealing nothing.

	This was the `df1 == "Luck" or df2 == "Luck"` branch of the legacy Damage module,
	which set the damage to 0 and let the hit carry on. It does the same here: the hit
	is not cancelled (no "blocked" visual, defense is still trained), it is just worth 0.
	As in that module the true-damage part of the hit (TrueDamage perk) was set aside
	before and is still dealt, and the branch sat after the shield and the Dark fruit's
	rules: a hit that comes to nothing has already worn the shield down.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local FRUIT = "Luck"
local CHANCE = 0.15

local random = Random.new()

return {
	Name = "LuckNullify",
	-- Where the legacy branch sat: after the shield (200) and Dark (210, 215), before the
	-- target's resistances (300).
	Priority = 220,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		if not data then
			return
		end

		local fruits = data.Data.DevilFruits
		if fruits.Slot1.Name ~= FRUIT and fruits.Slot2.Name ~= FRUIT then
			return
		end

		if random:NextNumber() < CHANCE then
			context.Amount = 0
		end
	end,
} :: CombatTypes.DamageModifier
