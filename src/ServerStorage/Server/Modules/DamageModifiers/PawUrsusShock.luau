--!strict
--[[
	Paw fruit - Ursus Shock: while the paw is held (PawUrsusShock status, set by the
	ability) a hit deals nothing and its amount is added to the user's PawUrsusTaken status,
	which sizes the paw.

	The source Damage module did this near its end: after the observation dodge, the
	shield (which the hit had already used up) and every resistance, with the true-damage
	share added back, and before the logia immunities. So what is swallowed is the final
	amount of the hit, not what the attack asked for; hence the late priority. One
	difference follows from the order of the modifiers here: a hit a logia immunity cancels
	never reaches this one and is not counted (in the source it was counted first).

	The sea is not a hit to swallow. The source's WaterDamage took health directly, past
	the Damage module, so a held paw never saw it; here the sea goes through the pipeline
	(WaterService) and the paw used to swallow every tick of it, growing while its user
	sat unharmed in the water. A sea hit now is left alone - it hurts as it hurts anyone,
	nothing is added to the damage taken - and tells the ability, which throws the paw
	(Paw.TouchedWater; see Abilities/Paw/_Shared).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Paw = require(ServerStorage.Server.Modules.Abilities.Paw._Shared)

local WATER_TAG = MovementConfig.Water.Tag
local STATUS = "PawUrsusShock"
local TAKEN_STATUS = "PawUrsusTaken"

return {
	Name = "PawUrsusShock",
	-- After shield (200), resistances (300) and the body reductions (400-420); before the
	-- Phoenix egg (100000), which must not see a hit that deals nothing.
	Priority = 500,
	Apply = function(context: CombatTypes.DamageContext)
		local target = context.Target
		if not target:HasStatus(STATUS) then
			return
		end

		-- Same test as WaterTrueDamage: only WaterService's own hit, never an attack that
		-- happens to carry the tag.
		if context.Tag == WATER_TAG and context.Style == "Environment" and not context.Attacker then
			Paw.TouchedWater(target)
			return
		end

		local taken = target:GetStatus(TAKEN_STATUS)
		local amount = math.max(0, context.Amount) + context.TrueAmount
		target:SetStatus(TAKEN_STATUS, (if type(taken) == "number" then taken else 0) + amount, nil, true)

		context.Cancelled = true
		context.CancelReason = "PawUrsusShock"
	end,
} :: CombatTypes.DamageModifier
