--!strict
--[[
	Gas fruit passive - logia body.

	Owning the fruit makes plain "Melee" and "Sword" hits pass through: the "MeleeImmunity"
	and "SwordImmunity" statuses are what DamageModifiers.Immunity reads. Haki, special
	and bleed damage are unaffected.

	When it is lost: the legacy Logia script recomputed the two flags only when a fruit
	slot changed (and the Legendary reset cleared them together with the fruit). A sealed
	fruit (seastone, water) kept its immunity, and so it does here: the cleanup runs when
	the character or the fruit goes away, nothing else.

	Pass-through visual: when one of those hits is negated the body turns to gas for a
	second. CombatService.Blocked provides the moment; the replicated, timed "GasLogia"
	status (value: fruit colors) drives Effects.Status.GasLogia. As in the legacy
	LogiaModule it cannot retrigger for 1.2s.

	With two logia fruits both passives set the same immunity statuses. AbilityService
	stops every passive before restarting the remaining ones, so the cleanup of one never
	strips the immunity the other still grants.

	Not ported: the legacy effect was skipped while a "body" transformation of another
	fruit was active (Candy, Magma, Venom, Snow, Gum second gear) so it would not fight
	over the body color. The client effect restores exactly what it changed instead.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local MELEE_STATUS = "MeleeImmunity"
local SWORD_STATUS = "SwordImmunity"
local EFFECT_STATUS = "GasLogia"
local IMMUNE_REASON = "Immune"

local EFFECT_SECONDS = 1
local EFFECT_COOLDOWN = 1.2

return function(entity: any, _player: Player, data: any, fruitSlot: number): () -> ()
	entity:SetStatus(MELEE_STATUS, true)
	entity:SetStatus(SWORD_STATUS, true)

	local lastEffect = 0
	local connection = Knit.GetService("CombatService").Blocked:Connect(function(context: any)
		if context.Target ~= entity or context.CancelReason ~= IMMUNE_REASON then
			return
		end

		local now = os.clock()
		if now - lastEffect < EFFECT_COOLDOWN then
			return
		end
		lastEffect = now

		local fruits = data.Data.DevilFruits
		local colors = if fruitSlot == 1 then fruits.Slot1.Color else fruits.Slot2.Color
		entity:SetStatus(EFFECT_STATUS, colors, EFFECT_SECONDS, true)
	end)

	return function()
		connection:Disconnect()
		entity:ClearStatus(MELEE_STATUS)
		entity:ClearStatus(SWORD_STATUS)
		entity:ClearStatus(EFFECT_STATUS)
	end
end
