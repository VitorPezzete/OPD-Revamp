--!strict
--[[
	Meteorite Sword - special: a meteorite shield of 6500 points (13000 for a Gravity
	user) for 2 seconds. Usable while fruit powers are sealed. Cooldown 20 s.

	The shield is added on top of whatever shield the character already has and what is
	left of it is taken back after the 2 seconds. The legacy script tracked its own share
	through the Changed event of the shield value; here the share left is whatever
	exceeds the shield the character had before, at most the amount granted.

	The rock dome is Effects.Status.WeaponMeteoriteShield.
]]
local ServerStorage = game:GetService("ServerStorage")

local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)
local WeaponShared = require(script.Parent._Shared)

local STATUS = "WeaponMeteoriteShield"
local AMOUNT = 6500
local GRAVITY_MULTIPLIER = 2
local DURATION = 2

local MeteoriteSword: WeaponTypes.WeaponBehaviour = {}

function MeteoriteSword.Special(context: WeaponTypes.WeaponContext): boolean?
	local entity = context.Entity
	local amount = AMOUNT
	if WeaponShared.HasFruit(context.Data, "Gravity") then
		amount *= GRAVITY_MULTIPLIER
	end

	local before = entity.Shield
	entity:SetShield(before + amount)
	entity:SetStatus(STATUS, true, DURATION, true)

	task.delay(DURATION, function()
		if entity.Dead then
			return
		end
		local left = math.clamp(entity.Shield - before, 0, amount)
		if left > 0 then
			entity:SetShield(entity.Shield - left)
		end
	end)
	return true
end

return MeteoriteSword
