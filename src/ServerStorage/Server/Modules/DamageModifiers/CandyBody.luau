--!strict
--[[
	Candy fruit - Spike Body: flat damage reduction while the candy body is on.
	The ability stores the fraction (0.125 * defense affinity * defense level / cap) in
	the CandyBodyGuard status; nothing is recomputed per hit.

	This was the `UsingCandyBody` branch of the legacy Damage module.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local GUARD_STATUS = "CandyBodyGuard"

return {
	Name = "CandyBody",
	-- Right after Smelt's Silver Body (410), as in the legacy order.
	Priority = 420,
	Apply = function(context: CombatTypes.DamageContext)
		local reduction = context.Target:GetStatus(GUARD_STATUS)
		if type(reduction) == "number" then
			context.Amount *= 1 - math.clamp(reduction, 0, 1)
		end
	end,
} :: CombatTypes.DamageModifier
