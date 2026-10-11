--!strict
--[[
	Heat-proof fruits against Magma abilities (hits tagged by the abilities).

	Legacy rule, repeated as an `if fruit == ...` chain in every Magma hit handler, for a
	player victim owning Rumble, Smelt, Hot or Plasma:
	- attacker using armament haki (the hit is "Haki"): no exception;
	- tag "MagmaHeat" (Magma Body, Magma Pool, Magma Flow): a Rumble owner takes 1 point
	  of Melee damage, the others take nothing;
	- tag "MagmaEruption" (Great Eruption): nothing at all, Rumble included.
	NPCs have no fruit data and are never exempt.

	The burn left by Great Eruption / Magma Body / the Magma Gun is a separate
	damage-over-time (tag "MagmaBurn", always "Special"). The burn is applied to anyone,
	but its ticks do nothing to a player owning Rumble, Smelt, Hot, Magma or Plasma (the
	list of the legacy control script in the character; Luck, also in that list, has its
	own modifier for every damage over time).

	Runs before the Immunity modifier, so the 1 point of Melee damage is then judged
	like any other melee hit.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local HEAT_TAG = "MagmaHeat"
local ERUPTION_TAG = "MagmaEruption"
local BURN_TAG = "MagmaBurn"
local REDUCED_FRUIT = "Rumble"
local HEAT_PROOF: { [string]: boolean } = { Rumble = true, Smelt = true, Hot = true, Plasma = true }
local BURN_PROOF: { [string]: boolean } = { Rumble = true, Smelt = true, Hot = true, Magma = true, Plasma = true }

return {
	Name = "MagmaBurnImmunity",
	Priority = 40,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		local tag = context.Tag
		if not data or (tag ~= HEAT_TAG and tag ~= ERUPTION_TAG and tag ~= BURN_TAG) then
			return
		end

		local fruits = data.Data.DevilFruits
		local first, second = fruits.Slot1.Name, fruits.Slot2.Name

		if tag == BURN_TAG then
			if BURN_PROOF[first] or BURN_PROOF[second] then
				context.Cancelled = true
				context.CancelReason = "Immune"
			end
			return
		end

		if context.Trait == "Haki" or not (HEAT_PROOF[first] or HEAT_PROOF[second]) then
			return
		end

		if tag == HEAT_TAG and (first == REDUCED_FRUIT or second == REDUCED_FRUIT) then
			context.Trait = "Melee"
			context.Amount = 1
		else
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
