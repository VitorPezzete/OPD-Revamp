--!strict
--[[
	Vampire fruit - Shadow Step: damage taken is halved for the three seconds the
	vampire is a shadow. The ability sets the VampireShadowStep status; the legacy
	Damage module checked the UsingVampireFly flag plus the fruit name on every hit.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "VampireShadowStep"
local DAMAGE_TAKEN = 0.5

return {
	Name = "VampireShadowStep",
	-- Right before Smelt's Silver Body (410), where the legacy branch sat.
	Priority = 405,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Target:HasStatus(STATUS) then
			context.Amount *= DAMAGE_TAKEN
		end
	end,
} :: CombatTypes.DamageModifier
