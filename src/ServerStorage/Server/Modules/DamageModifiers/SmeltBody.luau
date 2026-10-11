--!strict
--[[
	Smelt fruit - Silver Body: flat damage reduction while the body is coated.
	The ability stores the fraction (0.125 * defense affinity * defense level / cap) in
	the SmeltBodyGuard status; nothing is recomputed per hit.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local GUARD_STATUS = "SmeltBodyGuard"

return {
	Name = "SmeltBody",
	-- After shield (200), perk resistances (300) and Diamond Body (400), as in the legacy order.
	Priority = 410,
	Apply = function(context: CombatTypes.DamageContext)
		local reduction = context.Target:GetStatus(GUARD_STATUS)
		if type(reduction) == "number" then
			context.Amount *= 1 - math.clamp(reduction, 0, 1)
		end
	end,
} :: CombatTypes.DamageModifier
