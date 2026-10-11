--!strict
--[[
	Conqueror's Haki: nothing hurts the user in the instant the burst leaves, nor either
	of two users for as long as their clash holds. ConquerorService sets the timed
	ConquerorGuard status for both; it ends by itself.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local GUARD_STATUS = ConquerorConfig.Status.Guard

return {
	Name = "ConquerorGuard",
	-- Right after the logia immunities (50): a negated hit must not burn shield.
	Priority = 60,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Target:HasStatus(GUARD_STATUS) then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
