--!strict
--[[
	Lightning Sword - special: Lightning Slash. For 10 s everything the user deals is
	multiplied (x1.25, x1.5 with Rumble or Plasma, x2.25 with both): the multiplier itself
	is DamageModifiers.RumbleLightningSlash, gated by the status raised here, and the red
	sparks around the body are Effects.Status.RumbleLightningSlash.
	Cooldown 20 s (AttackConfig).
]]
local ServerStorage = game:GetService("ServerStorage")

local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

local STATUS = "RumbleLightningSlash"
local DURATION = 10

local LightningSword: WeaponTypes.WeaponBehaviour = {}

function LightningSword.Special(context: WeaponTypes.WeaponContext): boolean?
	context.Entity:SetStatus(STATUS, true, DURATION, true)
	return true
end

return LightningSword
