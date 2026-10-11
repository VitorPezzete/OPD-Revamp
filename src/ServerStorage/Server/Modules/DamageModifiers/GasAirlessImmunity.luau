--!strict
--[[
	Luck fruit against Airless World (hits tagged "GasAirless": the aura's own and the
	damage-over-time it leaves behind when it ends).

	Legacy rule, in the GasAirless control script cloned into player characters: a victim
	owning the Luck fruit never took the suffocation damage (the script switched the
	effect off instead of hurting it). NPCs have no fruit data and are never exempt.

	LuckDotImmunity cannot do this one: it recognises StatusService ticks, and while the
	aura is on Airless World deals its growing hits itself.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local TAG = "GasAirless"
local IMMUNE_FRUIT = "Luck"

return {
	Name = "GasAirlessImmunity",
	Priority = 40,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		if context.Tag ~= TAG or not data then
			return
		end

		local fruits = data.Data.DevilFruits
		if fruits.Slot1.Name == IMMUNE_FRUIT or fruits.Slot2.Name == IMMUNE_FRUIT then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
