--!strict
--[[
	Divine Axe - the axe of the sun.

	Swing: sword level + 300 + haki level / 3. For a Flare user that is multiplied by the
	sun: clamp(10 - 3 * (clock - 12)^2, 1, 10), i.e. x10 at noon, x1 before ~10:16 and
	after ~13:44 (haki x2 and the perk are applied afterwards, as for every weapon).

	Special - Cruel Sun (daytime only, 07:00 to 18:00; cooldown 20 s): for 3 seconds a
	sun burns above the axe. Ten times per second everyone within 50 studs of the axe
	hand (100 for a Flare user) takes 200 * clamp(10 - (clock - 12)^2, 2.5, 10) Special
	damage (x1.25 for a Flare user), which cannot be dodged. It ends early if the axe is
	put away. The cooldown is not spent when it is refused at night.

	The sun is Effects.Status.WeaponDivineAxeSun (value: its diameter).

	Legacy problem fixed: the area was GetPartBoundsInRadius over every part within 100
	studs, ten times per second.
]]
local ServerStorage = game:GetService("ServerStorage")

local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)
local WeaponShared = require(script.Parent._Shared)

type WeaponContext = WeaponTypes.WeaponContext

local FRUIT = "Flare"
local STATUS = "WeaponDivineAxeSun"

local SWING_BASE = 300
local SWING_HAKI_DIVISOR = 3
local SWING_SUN_SLOPE = 3

local SUN_TICKS = 30
local SUN_INTERVAL = 0.1
local SUN_DAMAGE = 200
local SUN_RADIUS = 50
local SUN_MIN = 2.5
local SUN_MAX = 10
local FLARE_RADIUS_MULTIPLIER = 2
local FLARE_DAMAGE_MULTIPLIER = 1.25

local DivineAxe: WeaponTypes.WeaponBehaviour = {}

function DivineAxe.GetDamage(context: WeaponContext, _base: number): number
	local damage = context.Level + SWING_BASE + context.Data.Data.Skills.Haki.Level / SWING_HAKI_DIVISOR
	if WeaponShared.HasFruit(context.Data, FRUIT) then
		local clock = WeaponShared.ClockTime()
		damage *= math.clamp(SUN_MAX - SWING_SUN_SLOPE * (clock - 12) ^ 2, 1, SUN_MAX)
	end
	return damage
end

function DivineAxe.Special(context: WeaponContext): boolean?
	if not WeaponShared.IsDaytime() then
		return false
	end

	local entity = context.Entity
	local flare = WeaponShared.HasFruit(context.Data, FRUIT)
	local radius = if flare then SUN_RADIUS * FLARE_RADIUS_MULTIPLIER else SUN_RADIUS
	entity:SetStatus(STATUS, radius * 2, SUN_TICKS * SUN_INTERVAL, true)

	local function burn(left: number)
		if not context:IsHolding() then
			entity:ClearStatus(STATUS)
			return
		end

		local clock = WeaponShared.ClockTime()
		local damage = SUN_DAMAGE * math.clamp(SUN_MAX - (clock - 12) ^ 2, SUN_MIN, SUN_MAX)
		if flare then
			damage *= FLARE_DAMAGE_MULTIPLIER
		end

		local center = WeaponShared.LimbPosition(entity, "Right Arm")
		for _, target in Hitbox.Sphere(center, radius, entity) do
			context.Services.Combat:Damage({
				Target = target,
				Attacker = entity,
				Amount = damage,
				Trait = "Special",
				Style = "Weapon",
				Dodgeable = false,
			})
		end

		if left > 1 then
			task.delay(SUN_INTERVAL, burn, left - 1)
		end
	end
	-- Legacy waited one interval before the first burn.
	task.delay(SUN_INTERVAL, burn, SUN_TICKS)
	return true
end

return DivineAxe
