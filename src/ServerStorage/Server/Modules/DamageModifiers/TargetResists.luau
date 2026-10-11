--!strict
-- Defensive expertise perks of a player target.
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local RESIST_WEAPONS = 0.02
local RESIST_ABILITIES = 0.005
local RESIST_HAKI = 0.005
local RESIST_GENERAL = 0.004

return {
	Name = "TargetResists",
	Priority = 300,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		if not data then
			return
		end

		local perks = data.Data.Expertise.Perks
		local amount = context.Amount

		if context.Style == "Weapon" then
			amount *= 1 - perks.ResistWeapons.Value * RESIST_WEAPONS
		elseif context.Style == "Ability" then
			amount *= 1 - perks.ResistAbilities.Value * RESIST_ABILITIES
		end
		if context.Trait == "Haki" then
			amount *= 1 - perks.ResistHaki.Value * RESIST_HAKI
		end

		context.Amount = amount * (1 - perks.ResistGeneral.Value * RESIST_GENERAL)
	end,
} :: CombatTypes.DamageModifier
