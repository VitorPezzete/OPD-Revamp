--!strict
--[[
	Hot Body does not burn Rumble or Plasma users (hits tagged "HotBody" by the ability).

	Legacy rule, from an `if fruit == ...` chain inside the Hot fruit's touch handler:
	- attacker using armament haki: no exception, full Haki damage;
	- victim has Rumble (either slot): the burn becomes 1 point of Melee damage;
	- otherwise victim has Plasma: no damage at all, the victim only gets the defense
	  exp every received hit gives (CombatService already awards it for negated hits).

	Runs before the Immunity modifier, so the 1 point of Melee damage is then judged
	like any other melee hit (a logia with melee immunity negates it).
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local TAG = "HotBody"
local REDUCED_FRUIT = "Rumble"
local IMMUNE_FRUIT = "Plasma"

return {
	Name = "HotBurnImmunity",
	Priority = 40,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		if context.Tag ~= TAG or context.Trait == "Haki" or not data then
			return
		end

		local fruits = data.Data.DevilFruits
		local first, second = fruits.Slot1.Name, fruits.Slot2.Name
		if first == REDUCED_FRUIT or second == REDUCED_FRUIT then
			context.Trait = "Melee"
			context.Amount = 1
		elseif first == IMMUNE_FRUIT or second == IMMUNE_FRUIT then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
