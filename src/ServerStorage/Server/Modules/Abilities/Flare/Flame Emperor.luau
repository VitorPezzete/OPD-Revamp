--!strict
--[[
	Flare fruit - Flame Emperor (charged): a sun grown above the head, then thrown.

	Charge: 25 per second held, 4 to 500 (20 s for a full charge, timed on the server).
	With k = sniper affinity * (sniper level / cap):
	- while charging the sun floats above the caster and grows:
	    diameter = min(1 + 2.6176 * k * seconds, 44.5 * k)
	    height   = 10 + min(1.75 * k * seconds, 30 * k) studs above the root
	  (clients draw it from the replicated status, Effects.Status.FlareSunCharging);
	- on release it flies towards the aim point at 100 studs/s with the size it reached,
	  for at most 20 s; it stops at the first thing its core touches and burns out 2 s
	  later;
	- every 0.1 s everyone whose root is within its radius takes
	  1000 * k * (charge / 500), Special, not dodgeable; armament haki at release doubles
	  it and makes it Haki. No burn.

	Rumble / Smelt / Hot / Magma / Plasma owners take no damage
	(DamageModifiers.FlareBurnImmunity, tag "FlareHeat").

	Cooldown: 3 s after a release, taken from a wait in the legacy client script (the
	legacy server had none). As in that script it cannot be charged while Flame Pillar is.

	KeepThroughStun: a sun already thrown keeps burning when its caster is stunned, as the
	legacy part did. A charge cannot start, and a release is dropped, while stunned.

	Legacy problems fixed here:
	- The sun was a server part resized every Heartbeat while charging, with a second
	  script growing its particles in a `while true` loop, and a damage script running a
	  Heartbeat loop over every player and enemy that was never disconnected.
	- Releasing without a sun (charge interrupted) indexed nil.

	Divine Axe: owning it triples the limits, as in the legacy game: charge up to 1500
	(60 s), diameter up to 133.5 * k, height up to 10 + 90 * k. Growth rates and the
	damage formula are unchanged (so up to 3000 * k per tick). The status carries the
	factor as its third field.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local CHARGE_STATUS = "FlareSunCharging"
local PILLAR_CHARGE_STATUS = "FlarePillarCharging"
local EFFECT = "FlareSun"
local DAMAGE_TAG = "FlareHeat"
local STUN_STATUS = "Stunned"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 500
local COOLDOWN = 3
local AXE_ITEM = "Divine Axe"
local AXE_FACTOR = 3

local DAMAGE = 1000
local HAKI_MULTIPLIER = 2
local TICK_INTERVAL = 0.1

-- Growth while charging. Mirrored in Effects.Status.FlareSunCharging.
local START_SIZE = 1
local GROWTH = 2.617647059
local MAX_SIZE = 44.5
local BASE_HEIGHT = 10
local RISE = 1.75
local MAX_RISE = 30

local SPEED = 100
local FLIGHT_TIME = 20
local LINGER_TIME = 2
-- The legacy sun stopped when a small part at its centre touched something.
local CORE_RADIUS = 1
-- Hitbox.Sphere reaches a body's width past the radius it is given; the legacy sun
-- measured the distance to the root.
local BODY_RADIUS = 2.5

type Sun = {
	Start: number,
	Origin: Vector3,
	Direction: Vector3,
	Radius: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	StoppedAt: number?,
	StopPosition: Vector3?,
}

local FlameEmperor = Ability.extend()

FlameEmperor.KeepThroughStun = true

local function burn(self: any, sun: Sun, epoch: number)
	if (self.Epoch or 0) ~= epoch or self.Entity.Dead then
		return
	end

	local now = os.clock()
	local elapsed = now - sun.Start
	local stoppedAt = sun.StoppedAt
	if elapsed > FLIGHT_TIME + LINGER_TIME or (stoppedAt and now - stoppedAt >= LINGER_TIME) then
		return
	end

	local position = sun.StopPosition or (sun.Origin + sun.Direction * (SPEED * elapsed))
	for _, target in Hitbox.Sphere(position, sun.Radius - BODY_RADIUS, self.Entity) do
		self:Damage(target, sun.Damage, sun.Trait, DAMAGE_TAG, false)
	end

	task.delay(TICK_INTERVAL, burn, self, sun, epoch)
end

function FlameEmperor:CanBegin(): boolean
	local entity = self.Entity
	return os.clock() >= (self.ReadyAt or 0)
		and not entity:HasStatus(PILLAR_CHARGE_STATUS)
		and not entity:HasStatus(STUN_STATUS)
end

function FlameEmperor:OnBegin()
	local entity = self.Entity
	-- Press and release ground the flights for 3 s: AbilityService (Modules.FlightLock).

	local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	local factor = if self.Context.Data.Data.Items[AXE_ITEM] == true then AXE_FACTOR else 1
	self.Factor = factor
	self:BeginCharge(CHARGE_MAX * factor / CHARGE_RATE)
	entity:SetStatus(CHARGE_STATUS, string.format("%.4f|%s|%d", scale, self:GetColorString(), factor), nil, true)
end

function FlameEmperor:OnEnd(input: Ability.AbilityInput)
	local started: number? = self.ChargeStart
	local factor: number = self.Factor or 1
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX * factor)
	self.Entity:ClearStatus(CHARGE_STATUS)
	if not charge or not started or self.Entity:HasStatus(STUN_STATUS) then
		return
	end
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local entity = self.Entity
	local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	local held = os.clock() - started
	local size = math.min(START_SIZE + GROWTH * scale * held, math.max(MAX_SIZE * factor * scale, START_SIZE))
	local height = BASE_HEIGHT + math.min(RISE * scale * held, MAX_RISE * factor * scale)
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local origin = entity.Root.Position + Vector3.new(0, height, 0)
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = Projectile.Lead(entity, origin, direction.Unit, SPEED, SPEED * FLIGHT_TIME)

	local sun: Sun = {
		Start = os.clock(),
		Origin = origin,
		Direction = direction,
		Radius = size / 2,
		Damage = DAMAGE * scale * (charge / CHARGE_MAX) * (if haki then HAKI_MULTIPLIER else 1),
		Trait = if haki then "Haki" else "Special",
		StoppedAt = nil,
		StopPosition = nil,
	}

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Speed = SPEED,
		Range = SPEED * FLIGHT_TIME,
		Size = size,
		-- Seconds charged: the glow, the light and the particles grew with time, not size.
		Held = held,
		Scale = scale * factor,
		LingerTime = LINGER_TIME,
		Haki = haki,
	})

	-- Only used to know where the sun stops; the damage is the area ticked by `burn`.
	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = SPEED,
		MaxDistance = SPEED * FLIGHT_TIME,
		Radius = CORE_RADIUS,
		Owner = entity,
		OnHit = function() end,
		OnEnd = function(position: Vector3)
			sun.StopPosition = position
			sun.StoppedAt = os.clock()
		end,
	})

	task.delay(TICK_INTERVAL, burn, self, sun, self.Epoch or 0)
end

function FlameEmperor:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
	-- A sun already thrown stops burning.
	self.Epoch = (self.Epoch or 0) + 1
end

return FlameEmperor
