--!strict
--[[
	Venom fruit passive: a player who has eaten the Venom fruit is immune to venom.

	The legacy VenomDoT control script of player characters had
	`burnimmune = {"Venom", "Luck"}`: the effect was still applied (and counted down),
	but its hits skipped owners of those fruits. Luck is covered for every DoT by
	LuckDotImmunity; this is the Venom half. The Alice fruit applied the same legacy
	effect; its port names it "AliceVenom", so that name is covered here as well.

	A tick is recognised as in LuckDotImmunity: StatusService deals it with
	Tag = the effect name while that effect is registered on the target. The first hit of
	VenomDoT is dealt by Abilities/Venom/_Shared itself (0.25 s after the application, as
	in legacy) with the same tag, while the target carries the status of that name.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local FRUIT = "Venom"
local DOTS: { [string]: boolean } = { VenomDoT = true, AliceVenom = true }

local statusService: any = nil

return {
	Name = "VenomDotImmunity",
	-- With the other immunities.
	Priority = 55,
	Apply = function(context: CombatTypes.DamageContext)
		local data = context.TargetData
		local tag = context.Tag
		if not tag or not DOTS[tag] or not data then
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
		if statusService:Has(context.Target, tag) or context.Target:HasStatus(tag) then
			context.Cancelled = true
			context.CancelReason = "Immune"
		end
	end,
} :: CombatTypes.DamageModifier
