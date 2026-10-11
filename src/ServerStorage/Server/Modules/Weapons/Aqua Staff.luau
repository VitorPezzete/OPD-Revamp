--!strict
--[[
	Aqua Staff - special: blesses its user with a Phoenix pulse worth 5000 health.

	Legacy raised the PhoenixPulse flag on the user with DoT = 5000 / max health, i.e.
	the pulse of the Phoenix fruit sized to heal a flat 5000: 32 parts, one every
	0.15625 s (5 s), under the same replicated "PhoenixPulse" status and visual.
	A character already under a pulse cannot start another (the legacy flag could not
	restart); the cooldown (20 s) is not spent in that case.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "PhoenixPulse"
local TOTAL_HEAL = 5000
local TICKS = 32
local INTERVAL = 0.15625

local AquaStaff: WeaponTypes.WeaponBehaviour = {}

local function healStep(target: CharacterEntity, left: number)
	if target.Dead then
		return
	end
	target:Heal(TOTAL_HEAL / TICKS)
	if left > 1 then
		task.delay(INTERVAL, healStep, target, left - 1)
	end
end

function AquaStaff.Special(context: WeaponTypes.WeaponContext): boolean?
	local entity = context.Entity
	if entity:HasStatus(STATUS) then
		return false
	end
	entity:SetStatus(STATUS, true, TICKS * INTERVAL, true)
	healStep(entity, TICKS)
	return true
end

return AquaStaff
