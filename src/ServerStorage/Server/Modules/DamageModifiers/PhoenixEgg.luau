--!strict
--[[
	Phoenix fruit - the egg. A Phoenix owner does not die from a hit: the hit is capped
	so 1 health is left and the owner turns into an egg; hits on the egg deal nothing and
	chip its "hits to crack" instead. The legacy Damage module had the
	`PhoenixEgg.Value == true` branch and HealthV2 the "do not die at 0" one.

	The rules and state live in Abilities.Phoenix._Shared (the passive needs them too).
]]
local ServerStorage = game:GetService("ServerStorage")

local PhoenixShared = require(ServerStorage.Server.Modules.Abilities.Phoenix._Shared)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

return {
	Name = "PhoenixEgg",
	-- Last of all: it has to see the amount every other modifier left.
	Priority = 100000,
	Apply = function(context: CombatTypes.DamageContext)
		PhoenixShared.OnDamage(context)
	end,
} :: CombatTypes.DamageModifier
