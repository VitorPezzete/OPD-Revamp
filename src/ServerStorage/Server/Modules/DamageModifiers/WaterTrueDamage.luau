--!strict
--[[
	Sea damage (WaterService) ignores every mitigation step: the legacy script subtracted
	10% of max health straight from the health value, past defense perks, shields and
	fruit bodies. The amount is moved to the true-damage part of the hit before any other
	modifier sees it.

	Still applied afterwards, because they act on true damage too: the Luck fruit's 15%
	nullify and the Phoenix egg.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local TAG = MovementConfig.Water.Tag

return {
	Name = "WaterTrueDamage",
	-- Before everything else (the first fruit modifiers start at 40).
	Priority = 30,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Tag ~= TAG or context.Style ~= "Environment" or context.Attacker then
			return
		end

		context.TrueAmount += context.Amount
		context.Amount = 0
	end,
} :: CombatTypes.DamageModifier
