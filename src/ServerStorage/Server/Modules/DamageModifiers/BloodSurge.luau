--!strict
--[[
	Blood fruit - Blood Surge: nothing can hurt the user for the half second (one second
	with Concentrate) after it reforms. The ability sets the timed BloodSurgeGuard
	status; the legacy game cleared the character's Spawned flag instead.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local GUARD_STATUS = "BloodSurgeGuard"

return {
	Name = "BloodSurge",
	-- Right after the logia immunities (50): a negated hit must not burn shield.
	Priority = 60,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Target:HasStatus(GUARD_STATUS) then
			context.Cancelled = true
			context.CancelReason = "BloodSurge"
		end
	end,
} :: CombatTypes.DamageModifier
