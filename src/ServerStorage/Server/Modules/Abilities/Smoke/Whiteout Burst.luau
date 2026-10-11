--!strict
--[[
	Smoke fruit - Whiteout Burst (charged): a stomp that blows a cloud of smoke around
	the caster, launching and choking everyone inside.

	Hold to charge, up to 10 seconds. On release, with
		f = (defense level / cap) * defense affinity / 20 * seconds held   (at least 0.1,
		    1 at level 500, affinity 2 and a full charge)
	- Everyone within 150 * f studs is carried upwards at 250 * f studs per second for
	  0.25s (the legacy BodyVelocity: infinite force on every axis, P = 10000, so the
	  victim also stops moving sideways for that long) and takes 10000 * f "Special"
	  damage (not dodgeable).
	- They then suffocate: ceil(10 * f) ticks (at most 10), one per second, the first one
	  together with the burst, of 200 * f "Special" damage each, walking at half speed
	  for as many seconds as there are ticks.
	- Everyone means everyone: crew mates are launched and slowed too, as before (their
	  damage is cancelled by the combat pipeline, as the legacy Damage module did).
	- Cooldown: the seconds held, between 1 and 10, from the release.
	- Pressing and releasing both ground the character's flights for 3s (legacy flight
	  disabler): done by AbilityService, see Modules.FlightLock.

	Suffocation is a StatusService DoT named "SmokeSuffocating" plus a slow. The
	replicated "SmokeSuffocating" status set next to it carries the caster's fruit
	colors for Effects.Status.SmokeSuffocating (smoke on the face and coughing), as the
	legacy smoke took them; the DoT's own status is "SmokeSuffocatingDot".
	The legacy `Suffocating` flag was what WS_Script read to halve the walk speed.

	Legacy problems fixed here:
	- The server waited 10 * f seconds and the client clamp(held, 1, 10) seconds before
	  the next burst. f is at most held / 10, so the client's wait was always the
	  longer one: that is the cooldown, enforced here.
	- A "Release" while the cooldown was running was dropped by the first line, leaving
	  `using` stuck on "whiteoutBurst" and the leg smoke attached for good.
	- One thread per victim ran the suffocation and wrote `Suffocating.Value` on
	  characters that could be gone by then.
	- Hits came from GetPartBoundsInRadius over the whole map (up to 150 studs).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local EFFECT = "SmokeWhiteoutBurst"
-- Replicated while charging: "<R or L>|<colors>", the leg the smoke gathers on.
local CHARGE_STATUS = "SmokeCharging"
local DOT_NAME = "SmokeSuffocating"
local DOT_STATUS = "SmokeSuffocatingDot"
local SUFFOCATING_STATUS = "SmokeSuffocating"
local SLOW_NAME = "SmokeSuffocatingSlow"
local FIST_STATUS = "SmokeFist"

local MAX_CHARGE_SECONDS = 10
-- EndCharge returns whole numbers: count hundredths of a second.
local CHARGE_RATE = 100
local FACTOR_DIVISOR = 20
local MIN_FACTOR = 0.1

local MAX_RADIUS = 150
local MAX_LAUNCH = 250
-- The legacy mover: BodyVelocity, MaxForce (inf, inf, inf), P = 10000, alive 0.25s.
local LAUNCH_SECONDS = 0.25
local LAUNCH_FORCE = Vector3.new(math.huge, math.huge, math.huge)
local LAUNCH_POWER = 10000
-- Legacy split of 12000: five sixths at once, one sixth over ten suffocation ticks.
local BURST_DAMAGE = 10000
local TICK_DAMAGE = 200
local MAX_TICKS = 10
local SLOW_SCALE = 0.5
local MIN_COOLDOWN = 1

local WhiteoutBurst = Ability.extend()

function WhiteoutBurst:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0) and not self.Entity:HasStatus(FIST_STATUS)
end

function WhiteoutBurst:OnBegin()
	local entity = self.Entity

	self:BeginCharge(MAX_CHARGE_SECONDS)
	-- The legs alternate from one burst to the next, left first.
	self.RightLeg = self.RightLeg == false
	entity:SetStatus(CHARGE_STATUS, `{if self.RightLeg then "R" else "L"}|{self:GetColorString()}`, nil, true)
end

function WhiteoutBurst:OnEnd()
	local entity = self.Entity
	local charge = self:EndCharge(CHARGE_RATE, 0, MAX_CHARGE_SECONDS * CHARGE_RATE)
	entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end

	local seconds = charge / CHARGE_RATE
	local factor = math.max(
		self:GetLevelScale("Defense") * self:GetAffinity("Defense") / FACTOR_DIVISOR * seconds,
		MIN_FACTOR
	)
	local cooldown = math.clamp(seconds, MIN_COOLDOWN, MAX_CHARGE_SECONDS)
	self.ReadyAt = os.clock() + cooldown
	self:StartCooldown(cooldown)

	local origin = entity.Root.Position
	local ticks = math.clamp(math.ceil(MAX_TICKS * factor), 1, MAX_TICKS)
	local status = self.Services.Status
	local colors = self:GetColorString()

	for _, target in Hitbox.Sphere(origin, MAX_RADIUS * factor, entity) do
		self:Impulse(target, Vector3.new(0, MAX_LAUNCH * factor, 0), LAUNCH_SECONDS, LAUNCH_FORCE, LAUNCH_POWER)
		self:Damage(target, BURST_DAMAGE * factor, "Special", EFFECT, false)
		-- First suffocation tick: it landed with the burst, the others follow every second.
		self:Damage(target, TICK_DAMAGE * factor, "Special", DOT_NAME, false)
		if not target.Dead then
			if ticks > 1 then
				status:ApplyDot(target, DOT_NAME, {
					Source = entity,
					Damage = TICK_DAMAGE * factor,
					Interval = 1,
					Ticks = ticks - 1,
					Trait = "Special",
					Status = DOT_STATUS,
				})
			end
			target:SetStatus(SUFFOCATING_STATUS, colors, ticks, true)
			status:ApplySlow(target, SLOW_NAME, SLOW_SCALE, ticks)
		end
	end

	self:PlayEffect(EFFECT, origin, { Factor = factor, RightLeg = self.RightLeg == true })
end

function WhiteoutBurst:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return WhiteoutBurst
