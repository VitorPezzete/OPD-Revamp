--!strict
--[[
	Venom fruit - Venom Demon: damage reduction while the demon is on.
	Legacy Damage module: `if UsingVenomDemon then damage *= 1 - 0.125 * defense affinity`.
	The ability stores the fraction (0.125 * defense affinity of the Venom slot) in the
	VenomDemonGuard status when it is toggled on; nothing is recomputed per hit.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local GUARD_STATUS = "VenomDemonGuard"

return {
	Name = "VenomDemon",
	-- After shield (200), perk resistances (300) and the body reductions (400, 410), as
	-- in the legacy order (it was the last reduction before the health subtraction).
	Priority = 420,
	Apply = function(context: CombatTypes.DamageContext)
		local reduction = context.Target:GetStatus(GUARD_STATUS)
		if type(reduction) == "number" then
			context.Amount *= 1 - math.clamp(reduction, 0, 1)
		end
	end,
} :: CombatTypes.DamageModifier
