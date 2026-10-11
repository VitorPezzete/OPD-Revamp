--!strict
--[[
	Dough fruit - a character stuck on someone's Torque Mochi does not take sea damage.

	The source set `DisableWaterDamage` on every caught character (WaterDamage skipped
	them): the ball sweeps over the sea and its victims have no say in where they are.
	The DoughTorqueCaught status, set and cleared by the ability, is that flag.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MovementConfig = require(ReplicatedStorage.Shared.Configs.MovementConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local TAG = MovementConfig.Water.Tag
local STATUS = "DoughTorqueCaught"

return {
	Name = "DoughTorqueWater",
	-- Before WaterTrueDamage (30) turns the hit into true damage.
	Priority = 25,
	Apply = function(context: CombatTypes.DamageContext)
		if context.Tag ~= TAG or context.Style ~= "Environment" or context.Attacker then
			return
		end
		if context.Target:HasStatus(STATUS) then
			context.Cancelled = true
			context.CancelReason = "DoughTorque"
		end
	end,
} :: CombatTypes.DamageModifier
