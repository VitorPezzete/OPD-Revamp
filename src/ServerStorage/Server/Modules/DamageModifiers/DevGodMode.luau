--!strict
--[[
	God mode of the developer menu: a character carrying the "DevGod" status takes no
	damage at all. Only DevService sets that status, after authorising the developer.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

return {
	Name = "DevGodMode",
	-- Lowest priority value runs first: nothing should be spent or triggered by a hit that never lands.
	Priority = 0,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Target:HasStatus("DevGod") then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
