--!strict
--[[
	Luck fruit passive: a player who has eaten the Luck fruit takes no damage over time.

	In the legacy game "Luck" was in the `burnimmune` list of every status control
	script (burn, magma burn, venom, candy, chilly, snow, gas, love, negative): the
	effect was still applied and shown, but its ticks skipped Luck owners.

	A DoT tick is recognised without knowing any effect by name: StatusService deals it
	with Tag = the effect's name while that effect is still registered on the target,
	so `StatusService:Has(target, tag)` is true exactly for ticks. As before, the effect
	itself stays (and keeps its visual) until it runs out.

	Not covered: the non-damage half of those legacy effects (slows, the love stun).
	StatusService has no hook to refuse a stun or a slow per target.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local FRUIT = "Luck"

local statusService: any = nil

return {
	Name = "LuckDotImmunity",
	-- With the other immunities.
	Priority = 55,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		local tag = context.Tag
		if not data or not tag then
			return
		end

		local fruits = data.Data.DevilFruits
		if fruits.Slot1.Name ~= FRUIT and fruits.Slot2.Name ~= FRUIT then
			return
		end

		-- Resolved on first use: this module is required during CombatService:KnitInit.
		if not statusService then
			statusService = Knit.GetService("StatusService")
		end
		if statusService:Has(context.Target, tag) then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
