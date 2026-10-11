--!strict
--[[
	Heat-proof fruits against Flare abilities.

	Direct hits (tagged "FlareHeat" by the abilities). Legacy rule, repeated in every
	Flare hit handler: a player victim owning Rumble, Smelt, Hot, Magma or Plasma takes no
	damage from Fire Fist, Fire Wave, Flame Pillar and Flame Emperor, unless the attacker
	uses armament haki (the hit is then "Haki").

	Burn ticks (tag "FlareBurn": the damage-over-time those abilities, and Roger in the
	hands of a Flare user, leave). The burn control script cloned into player characters
	skipped the damage of every tick for owners of Rumble, Smelt, Hot, Magma, Luck, Flare
	or Plasma, haki or not (Luck is also covered, for every damage-over-time, by
	LuckDotImmunity). The victim still carries the burn for its whole duration; a
	cancelled tick still trains defense (CombatService) and fires CombatService.Blocked,
	which is what the legacy "logia" flash of a burning Flare owner hangs on
	(Passives.Flare).

	NPCs have no fruit data and are never exempt (their copy of the burn script declared
	the list and never used it).
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local HEAT_TAG = "FlareHeat"
local BURN_TAG = "FlareBurn"
local HEAT_PROOF: { [string]: boolean } = { Rumble = true, Smelt = true, Hot = true, Magma = true, Plasma = true }
local BURN_PROOF: { [string]: boolean } = {
	Rumble = true,
	Smelt = true,
	Hot = true,
	Magma = true,
	Luck = true,
	Flare = true,
	Plasma = true,
}

return {
	Name = "FlareBurnImmunity",
	Priority = 40,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		if not data then
			return
		end

		local proof: { [string]: boolean }
		if context.Tag == HEAT_TAG and context.Trait ~= "Haki" then
			proof = HEAT_PROOF
		elseif context.Tag == BURN_TAG then
			proof = BURN_PROOF
		else
			return
		end

		local fruits = data.Data.DevilFruits
		if proof[fruits.Slot1.Name] or proof[fruits.Slot2.Name] then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
