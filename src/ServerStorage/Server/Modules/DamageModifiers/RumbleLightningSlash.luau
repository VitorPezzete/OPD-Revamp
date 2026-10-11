--!strict
--[[
	Lightning Slash: while an attacker is charged with lightning, everything it deals is
	multiplied, more so when its own body is lightning.

		Rumble and Plasma owned   x2.25
		Rumble or Plasma owned    x1.5
		neither                   x1.25

	Gate: the "RumbleLightningSlash" status on the ATTACKER. In the legacy game the flag
	(LightningSlash) was not raised by either fruit but by the special attack of the
	Lightning Sword weapon, for 10 seconds; whatever ports that attack only has to call
		entity:SetStatus("RumbleLightningSlash", true, 10, true)
	(Effects.Status.RumbleLightningSlash draws the sparks around the body).

	As in the legacy Damage module it applies to player attackers only, after the
	offensive perks (so the true-damage share split off by the TrueDamage perk is not
	multiplied) and before every mitigation of the target.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "RumbleLightningSlash"

local BOTH_FRUITS = 2.25
local ONE_FRUIT = 1.5
local NO_FRUIT = 1.25

local function apply(context: CombatTypes.DamageContext)
	local attacker, data = context.Attacker, context.AttackerData
	if not attacker or not data or not attacker:HasStatus(STATUS) then
		return
	end

	local fruits = data.Data.DevilFruits
	local first, second = fruits.Slot1.Name, fruits.Slot2.Name
	local rumble = first == "Rumble" or second == "Rumble"
	local plasma = first == "Plasma" or second == "Plasma"

	if rumble and plasma then
		context.Amount *= BOTH_FRUITS
	elseif rumble or plasma then
		context.Amount *= ONE_FRUIT
	else
		context.Amount *= NO_FRUIT
	end
end

return {
	Name = "RumbleLightningSlash",
	-- Right after AttackerPerks (100), before LuckNullify (150) and the shield (200).
	Priority = 110,
	Apply = apply,
} :: CombatTypes.DamageModifier
