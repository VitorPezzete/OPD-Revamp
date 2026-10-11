--!strict
--[[
	Alice fruit - Looking Glass. An attacker carrying the "AliceLookingGlass" status
	(value: UserId of the Alice user who cursed it, set by the ability for 5 s) cannot
	damage any player: the hit is cancelled. NPCs are still hurt.

	This was the `attacker.Character.Alice.Effect2` branch of the legacy Damage module.
	See Abilities/Alice/Looking Glass for why it covers every player and not only the
	caster.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "AliceLookingGlass"
-- Switched off for now by the owner: the ability still casts, costs its haki and marks
-- its victims, but the mark does nothing to their damage until what it should block is
-- decided (the legacy outcome, "no damage to any player", came from an error).
local ENABLED = false

return {
	Name = "AliceLookingGlass",
	-- Before immunities, dodges and shields: nothing of the target's is spent on the hit.
	Priority = 45,
	Apply = function(context: CombatTypes.DamageContext)
		local attacker = context.Attacker
		local targetPlayer = context.Target.Player
		if not ENABLED or not attacker or not targetPlayer then
			return
		end

		if attacker.Player and attacker:HasStatus(STATUS) then
			context.Cancelled = true
			context.CancelReason = "LookingGlass"
		end
	end,
} :: CombatTypes.DamageModifier
