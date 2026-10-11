--!strict
--[[
	Dark fruit - Dark Charge: while the user is charging, a hit deals nothing and adds
	twice its amount to the charge instead, up to the cap the ability computed
	(5000 * defense affinity * defense level / cap).

	The ability publishes a { Charge, Cap, Absorbed } table in the DarkChargeState status
	and reads the total back when it releases; nothing else is looked up per hit.
	`Absorbed` is called after each swallowed hit (the ability resizes the user's guide
	disc there).

	As in the legacy Damage module, the amount absorbed is what is left after the shield
	(the shield still soaks first) and before the resistance perks. The true-damage share
	of a hit (attacker's perk) is swallowed with the rest but not counted, as before.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATE_STATUS = "DarkChargeState"
local ABSORB_MULTIPLIER = 2

return {
	Name = "DarkCharge",
	-- Right after the shield (200), before the resistance perks (300).
	Priority = 210,
	Apply = function(context: CombatTypes.DamageContext)
		local state = context.Target:GetStatus(STATE_STATUS)
		if type(state) ~= "table" or type(state.Charge) ~= "number" or type(state.Cap) ~= "number" then
			return
		end

		local absorbed = context.Amount * ABSORB_MULTIPLIER
		state.Charge = math.min(state.Charge + absorbed, math.max(state.Cap, state.Charge))
		context.Cancelled = true
		context.CancelReason = "DarkCharge"

		if type(state.Absorbed) == "function" then
			state.Absorbed()
		end
	end,
} :: CombatTypes.DamageModifier
