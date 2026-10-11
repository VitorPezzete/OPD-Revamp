--!strict
--[[
	Love fruit - damage rules of a petrified character (the "Love Effect" branch of the
	legacy Damage module). Reads the LoveStunState status written by the Love abilities
	(Abilities/Love/_Shared).

	- Victim of a Love user: the hit is multiplied by (1 + sniper affinity / 4) of that
	  Love user, whoever the attacker is.
	- Love user inside its own Petrify: the hit is multiplied by
	  (1 - 0.25 - 0.325 * sniper affinity), i.e. 42.5% taken at affinity 1 and 10% at 2.
	- For a player the incoming amount (before the multiplier) is taken from the
	  petrification's threshold; at zero it breaks. NPC enemies have no threshold: the
	  legacy enemy script only ran the timer, so they stay petrified, and amplified, for
	  the whole duration however hard they are hit.

	The Love user's own Petrify loses the hit from its threshold TWICE, as in the legacy
	code (the line was duplicated in both fruit-slot branches): its stone really holds
	half of the 5000 * (defense level / cap) * defense affinity it is given.

	Legacy differences:
	- The threshold was polled by a separate loop every 0.1 s; it breaks on the hit now.
	- The true-damage part of a hit (TrueDamage perk) was split off before this branch
	  and is not multiplied, as before.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Love = require(ServerStorage.Server.Modules.Abilities.Love._Shared)

local SELF_BASE_REDUCTION = 0.25
local SELF_REDUCTION_PER_AFFINITY = 0.325
local VICTIM_BONUS_DIVISOR = 4
-- Times a hit is taken from the threshold of the user's own Petrify.
local SELF_THRESHOLD_COST = 2

return {
	Name = "LoveStunned",
	-- Where the legacy branch sat: after the attacker's perks (100), before the shield (200).
	Priority = 150,
	Apply = function(context: CombatTypes.DamageContext)
		local target = context.Target
		local state: Love.State? = target:GetStatus(Love.STATE)
		if not state then
			return
		end

		-- The legacy game dropped the petrification when the Love user had left.
		if not state.Self and state.Owner.Model.Parent == nil then
			Love.Release(target)
			return
		end

		local amount = context.Amount
		if amount <= 0 then
			return
		end

		if state.Self then
			local taken = 1 - SELF_BASE_REDUCTION - SELF_REDUCTION_PER_AFFINITY * state.SniperAffinity
			context.Amount = amount * math.max(taken, 0)
		else
			context.Amount = amount * (1 + state.SniperAffinity / VICTIM_BONUS_DIVISOR)
		end

		if target.Player then
			state.Threshold -= if state.Self then amount * SELF_THRESHOLD_COST else amount
			if state.Threshold <= 0 then
				Love.Release(target)
			end
		end
	end,
} :: CombatTypes.DamageModifier
