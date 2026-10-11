--!strict
--[[
	Barrier fruit - Barrier Body: while the body is up (BarrierBody status, set by the
	ability) the user takes no damage of any kind.

	The legacy Damage module simply returned when the character's UsingBarrierBody flag
	was set (halfway down, after the per-fruit branches). Here the hit is cancelled
	before the shield, observation dodge and on-hit perks, so a negated hit costs the
	user nothing.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "BarrierBody"

return {
	Name = "BarrierBody",
	-- Right after the logia immunities (50), before observation dodge (60) and shield (200).
	Priority = 55,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Target:HasStatus(STATUS) then
			context.Cancelled = true
			context.CancelReason = "BarrierBody"
		end
	end,
} :: CombatTypes.DamageModifier
