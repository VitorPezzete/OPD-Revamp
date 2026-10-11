--!strict
-- Shields soak damage before any resistance is applied.
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

return {
	Name = "Shield",
	Priority = 200,
	Apply = function(context: CombatTypes.DamageContext)
		context.Amount = context.Target:AbsorbWithShield(context.Amount)
	end,
} :: CombatTypes.DamageModifier
