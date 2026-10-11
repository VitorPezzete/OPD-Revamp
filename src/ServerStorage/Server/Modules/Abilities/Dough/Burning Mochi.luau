--!strict
--[[
	Dough fruit - Burning Mochi (charged): a burning mochi fist grows on the right arm
	while the key is held, is thrown at the aim point on release and explodes on the first
	thing it meets.

	With f0 = Shared.Factor (sniper), t = seconds held clamped to 0.5 - 5 and
	f = f0 / 5 * t:
	- flight: straight from the right hand towards the aim point. The source moved the
	  fist by clamp(5 * f, 2.5, 5) studs every Heartbeat ("not in studs/s"), i.e. 150 to
	  300 studs per second on a 60 Hz server; that speed is used whatever the frame rate.
	  It flies for 5 * f seconds at most.
	- it explodes when it touches anything that is not its user (the source tested the
	  fist's bounding box, about 2 studs across: a sphere of radius 1 here), when it goes
	  under the sea (Y < 210.5 in the source) or when its time is up.
	- explosion, with e = f / 2 (e = f when armament haki was on AT THE PRESS - the source
	  stored the flag in the fist when it was created): everyone within 150 * e studs
	  takes 8000 * e Special damage, not dodgeable, and is pushed away from the centre at
	  500 * e studs per second for 0.5 s (BodyVelocity, MaxForce inf, P 100000). The push
	  is applied whether or not the damage was negated, as in the source.
	- cooldown: 1 s from the release.

	The source's flight was a Heartbeat loop moving an anchored server model; it is a
	Projectile here and the fist is drawn by the clients (Effects.Status.DoughCharging
	while charging, Effects.OneShot.DoughBurningMochi in flight, DoughExplosion at the end).

	Source bug fixed: a release while the powers were sealed was never sent, which left the
	fist on the arm and the fruit locked until respawn. A seal / stun / death cancels the
	charge here (OnInterrupt).

	Flight lock: the source client raised it on the press and on the release. The press is
	AbilityService's default; the release is raised here until FlightLock lists this
	ability as "Both".
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WorldConfig = require(ReplicatedStorage.Shared.Configs.WorldConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local Shared = require(script.Parent._Shared)

local NAME = "Burning Mochi"
local SKILL = "Sniper"
local FLIGHT_EFFECT = "DoughBurningMochi"
local EXPLOSION_EFFECT = "DoughExplosion"
local DAMAGE_TAG = "DoughBurningMochi"

local COOLDOWN = 1
local MIN_CHARGE = 0.5
local MAX_CHARGE = 5
local MAX_DAMAGE = 8000
-- Studs per source Heartbeat, and the Heartbeats per second it ran at.
local MAX_STEP = 5
local SOURCE_RATE = 60
local MAX_RANGE = 300
local LIFETIME = 5
local KNOCKBACK = 500
local KNOCKBACK_TIME = 0.5
local KNOCKBACK_FORCE = Vector3.new(math.huge, math.huge, math.huge)
local KNOCKBACK_POWER = 100000
-- Half the width of the flying fist.
local RADIUS = 1
-- The fist sat half a stud below the centre of the right arm.
local HAND_OFFSET = CFrame.new(0, -0.5, 0)
-- The source's fixed `Y < 210.5`: half a stud under the sea surface.
local SEA_Y = WorldConfig.SeaLevel - 0.5
local MIN_DISTANCE = 0.1

local BurningMochi = Ability.extend()
-- The source dealt this damage without a style: ResistAbilities does not apply.
BurningMochi.DamageStyle = "Plain"

function BurningMochi:CanBegin(): boolean
	return not self.Charging and os.clock() >= (self.ReadyAt or 0) and not Shared.IsUsing(self.Entity)
end

function BurningMochi:OnBegin()
	local entity = self.Entity
	self.Charging = true
	self.Haki = Shared.Haki(self)
	Shared.SetUsing(entity, NAME)
	self:BeginCharge(MAX_CHARGE)
	entity:SetStatus(Shared.ChargingStatus, `Burning|{if self.Haki then 1 else 0}|{self:GetColorString()}`, nil, true)
end

function BurningMochi:Explode(position: Vector3, factor: number)
	local entity = self.Entity
	if factor <= 0 then
		return
	end

	for _, target in Hitbox.Sphere(position, MAX_RANGE / 2 * factor, entity) do
		self:Damage(target, MAX_DAMAGE * factor, "Special", DAMAGE_TAG, false)
		if not target.Dead then
			local away = Shared.TorsoPosition(target) - position
			if away.Magnitude > 1e-3 then
				self:Impulse(target, away.Unit * KNOCKBACK * factor, KNOCKBACK_TIME, KNOCKBACK_FORCE, KNOCKBACK_POWER)
			end
		end
	end

	self:PlayEffect(EXPLOSION_EFFECT, position, { Factor = factor })
end

function BurningMochi:OnEnd(input: Ability.AbilityInput)
	if not self.Charging then
		return
	end
	local entity = self.Entity
	local held = Shared.HeldSeconds(self, MIN_CHARGE, MAX_CHARGE)
	local haki: boolean = self.Haki == true
	self:Cancel()
	if not held then
		return
	end

	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	self.Services.Ability:RaiseFlightLock(entity)

	local factor = Shared.Factor(self, SKILL) / MAX_CHARGE * held

	local arm = entity.Model:FindFirstChild("Right Arm")
	local origin = if arm and arm:IsA("BasePart") then (arm.CFrame * HAND_OFFSET).Position else entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit

	local speed = math.clamp(MAX_STEP * factor, MAX_STEP / 2, MAX_STEP) * SOURCE_RATE
	local distance = math.max(speed * LIFETIME * factor, MIN_DISTANCE)
	direction = Projectile.Lead(entity, origin, direction, speed, distance)

	-- The sea ends the flight where the line goes under it.
	if origin.Y < SEA_Y then
		distance = MIN_DISTANCE
	elseif direction.Y < -1e-4 then
		distance = math.clamp((origin.Y - SEA_Y) / -direction.Y, MIN_DISTANCE, distance)
	end

	local blast = if haki then factor else factor / 2

	self:PlayEffect(FLIGHT_EFFECT, origin, {
		Direction = direction,
		Speed = speed,
		Distance = distance,
		Radius = RADIUS,
		Haki = haki,
	})

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = speed,
		MaxDistance = distance,
		Radius = RADIUS,
		Owner = entity,
		HitOverlapping = true,
		-- The first character stops it; the explosion (OnEnd) does the damage.
		OnHit = function() end,
		OnEnd = function(position: Vector3)
			self:Explode(position, blast)
		end,
	})
end

-- Ends the charge without throwing anything.
function BurningMochi:Cancel()
	self.Charging = false
	self.Entity:ClearStatus(Shared.ChargingStatus)
	Shared.ClearUsing(self.Entity, NAME)
end

function BurningMochi:OnInterrupt()
	if self.Charging then
		self:Cancel()
	end
end

return BurningMochi
