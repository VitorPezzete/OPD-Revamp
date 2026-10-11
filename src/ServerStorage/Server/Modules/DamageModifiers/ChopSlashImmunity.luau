--!strict
--[[
	Chop fruit passive: a body that is already in pieces cannot be cut. Any hit tagged
	"Slash" (sword swings) against a player who has eaten the Chop fruit is negated.

	This was an `Extra == "Slash" and fruit == "Chop"` branch inside the legacy Damage
	module. Like there, it only depends on owning the fruit (either slot), not on an
	ability being active, and it negates a slash whatever its trait (haki included). The
	other half of the legacy immunity, every plain "Sword" hit, is the SwordImmunity
	status set by Passives.Chop.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local FRUIT = "Chop"
local TAG = "Slash"

return {
	Name = "ChopSlashImmunity",
	-- With the other immunities: before shields and on-hit perks are spent.
	Priority = 55,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		if context.Tag ~= TAG or not data then
			return
		end

		local fruits = data.Data.DevilFruits
		if fruits.Slot1.Name == FRUIT or fruits.Slot2.Name == FRUIT then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
