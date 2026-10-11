--!strict
--[[
	Logia-style immunities. A fruit grants them by setting the "MeleeImmunity" /
	"SwordImmunity" status on its user; haki and special damage go through.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS_BY_TRAIT: { [string]: string } = {
	Melee = "MeleeImmunity",
	Sword = "SwordImmunity",
}

return {
	Name = "Immunity",
	-- Runs first so a negated hit does not burn shield or apply on-hit perks.
	Priority = 50,
	Apply = function(context: CombatTypes.DamageContext)
		local status = STATUS_BY_TRAIT[context.Trait]
		if status and context.Target:HasStatus(status) then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
