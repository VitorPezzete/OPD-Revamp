--!strict
--[[
	Blood fruit - Blood Supernova: two presses. The first throws drops of blood, the
	second (while they still exist) blows every drop up.

	First press (1 s cooldown, costs 5% of max health, doubled by Concentrate):
	  floor(5 * defense affinity) drops that live 4 s.
	  - Aimed at nobody: they scatter from the user in random directions (mostly
	    sideways, slightly up) at 100 studs per second for 0.75 s, then hang there.
	  - Aimed at a character (BloodShared.FindTarget, the legacy auto-aim): they appear
	    around the user (within 10 studs, up to 5 above), wait 0.25 s, then fly at 150
	    studs per second (200 with Concentrate) towards where the target stood when the
	    key was pressed.
	  A drop touching a character hits it once:
	    125 * defense affinity * (defense level / cap), doubled by Concentrate;
	    heals the user 75 * defense affinity (even when the hit itself was negated,
	    as in the legacy game).
	Second press (free, no cooldown): every drop explodes in a sphere of
	  10 * defense affinity studs: twice the contact damage; heals 25 * defense
	  affinity per character hit. Several drops can hit the same character.
	All damage is "Special", not dodgeable; heals are doubled by Concentrate. Concentrate
	is read when the drops are thrown for their contact damage and again when they are
	blown up for the explosion, as in the legacy game.

	Design: a drop is not an instance. Its motion is a straight line known at cast
	time, so the server only stores start, velocity and timing and evaluates the
	position when it needs it: ten times a second for contact (swept between two
	evaluations, so fast drops cannot skip a character) and once for the explosion.
	The same numbers are sent to the clients, which draw the drops (BloodSupernova).

	KeepThroughStun: drops already thrown keep flying when their user is stunned, as in
	the legacy game. A press while stunned (throw or detonation) is dropped.

	Legacy problems fixed here:
	- One unanchored part with a LinearVelocity and a Touched connection per drop.
	- "Are there drops?" was a folder lookup, and the drops were Debris items, so the
	  second press raced their removal.
	- The client chose the mode by sending (or not) a target part.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local BloodShared = require(script.Parent.BloodShared)

type CharacterEntity = CharacterEntity.CharacterEntity

type Drop = {
	Start: Vector3,
	Velocity: Vector3,
	-- Seconds after the cast at which the drop starts moving, and for how long it moves.
	Delay: number,
	MoveTime: number,
	Last: Vector3,
	Hit: { [CharacterEntity]: boolean },
}

local STUN_STATUS = "Stunned"

local COOLDOWN = 1
local HEALTH_COST = 5
local BASE_DAMAGE = 125
local DROPS_PER_AFFINITY = 5
local LIFETIME = 4
local TICK = 0.1
local DROP_RADIUS = 2
-- Same margin Hitbox gives every character.
local BODY_RADIUS = 2.5

local SPREAD = 10
local SPREAD_UP = 5
local SCATTER_SPEED = 100
local SCATTER_TIME = 0.75
local HOMING_DELAY = 0.25
local HOMING_SPEED = 150
local HOMING_SPEED_CONCENTRATED = 200

local EXPLOSION_RADIUS = 10
local EXPLOSION_MULTIPLIER = 2
local CONTACT_HEAL = 75
local EXPLOSION_HEAL = 25

local random = Random.new()

local function positionAt(drop: Drop, elapsed: number): Vector3
	return drop.Start + drop.Velocity * math.clamp(elapsed - drop.Delay, 0, drop.MoveTime)
end

local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	if lengthSquared < 1e-6 then
		return (point - from).Magnitude
	end
	local along = math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1)
	return (point - (from + segment * along)).Magnitude
end

local Supernova = Ability.extend()

Supernova.KeepThroughStun = true

function Supernova:CanBegin(): boolean
	if self.Entity:HasStatus(STUN_STATUS) then
		return false
	end
	-- The second press is free; only throwing new drops has a cooldown.
	return self.Active or os.clock() - (self.LastCast or 0) >= COOLDOWN
end

function Supernova:Detonate()
	local entity = self.Entity
	local drops: { Drop } = self.Drops
	local elapsed = os.clock() - self.StartedAt
	local damage: number = self.BaseDamage * EXPLOSION_MULTIPLIER * BloodShared.GetScale(entity)
	local affinity = self:GetAffinity("Defense")
	local radius = EXPLOSION_RADIUS * affinity

	-- Stop the contact ticks first: nothing below can then run against stale drops.
	self:Reset()

	local positions: { Vector3 } = {}
	for _, drop in drops do
		table.insert(positions, positionAt(drop, elapsed))
	end
	self:PlayEffect("BloodSupernova", entity.Root.Position, {
		Detonate = true,
		Positions = positions,
		Radius = radius,
	})

	for _, position in positions do
		for _, target in Hitbox.Sphere(position, radius, entity) do
			self:Damage(target, damage, "Special", nil, false)
			BloodShared.Heal(entity, EXPLOSION_HEAL * affinity)
		end
	end
end

function Supernova:OnBegin(input: Ability.AbilityInput)
	if self.Active then
		self:Detonate()
		return
	end

	local entity = self.Entity
	self.LastCast = os.clock()
	self:StartCooldown(COOLDOWN)
	BloodShared.PayHealth(entity, HEALTH_COST)
	if entity.Dead then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local concentrated = BloodShared.IsConcentrated(entity)
	local origin = entity.Root.Position
	local homingSpeed = if concentrated then HOMING_SPEED_CONCENTRATED else HOMING_SPEED
	-- The legacy auto-aim had no range: a far target is still flown at (and not reached).
	local target = BloodShared.FindTarget(entity, input.AimPosition, AbilityConfig.MaxAimDistance)
	local targetPosition = target and target.Root.Position

	local drops: { Drop } = {}
	-- One Vector3 per drop is all the clients need (the effect remote is size limited):
	-- its start when homing (they all fly at the target), its direction when scattering
	-- (they all leave from the origin).
	local points: { Vector3 } = {}
	for _ = 1, math.floor(DROPS_PER_AFFINITY * affinity) do
		local around = origin
			+ Vector3.new(
				random:NextInteger(-SPREAD, SPREAD),
				random:NextInteger(0, SPREAD_UP),
				random:NextInteger(-SPREAD, SPREAD)
			)

		local drop: Drop
		if targetPosition then
			local offset = targetPosition - around
			local direction = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.yAxis
			drop = {
				Start = around,
				Velocity = direction * homingSpeed,
				Delay = HOMING_DELAY,
				MoveTime = LIFETIME,
				Last = around,
				Hit = {},
			}
			table.insert(points, around)
		else
			local offset = around - origin
			local direction = if offset.Magnitude > 1e-3 then offset.Unit else Vector3.yAxis
			drop = {
				Start = origin,
				Velocity = direction * SCATTER_SPEED,
				Delay = 0,
				MoveTime = SCATTER_TIME,
				Last = origin,
				Hit = {},
			}
			table.insert(points, direction)
		end
		table.insert(drops, drop)
	end
	if #drops == 0 then
		return
	end

	local baseDamage = BASE_DAMAGE * affinity * self:GetLevelScale("Defense")
	local damage = baseDamage * (if concentrated then 2 else 1)

	self.Active = true
	self.Drops = drops
	self.StartedAt = os.clock()
	self.BaseDamage = baseDamage
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	local startedAt: number = self.StartedAt

	self:PlayEffect("BloodSupernova", origin, {
		Points = points,
		-- Present when homing: where every drop flies to.
		Target = targetPosition,
		Speed = if targetPosition then homingSpeed else SCATTER_SPEED,
		Delay = if targetPosition then HOMING_DELAY else 0,
		MoveTime = if targetPosition then LIFETIME else SCATTER_TIME,
		Life = LIFETIME,
		Concentrate = concentrated,
	})

	local function step()
		if self.Run ~= run then
			return
		end
		local elapsed = os.clock() - startedAt
		if elapsed >= LIFETIME or entity.Dead then
			self:Reset()
			return
		end

		for _, drop in drops do
			local position = positionAt(drop, elapsed)
			local previous = drop.Last
			drop.Last = position

			local travelled = (position - previous).Magnitude
			local candidates = Hitbox.Sphere((position + previous) / 2, DROP_RADIUS + travelled / 2, entity)
			for _, candidate in candidates do
				if
					not drop.Hit[candidate]
					and distanceToSegment(candidate.Root.Position, previous, position) <= DROP_RADIUS + BODY_RADIUS
				then
					drop.Hit[candidate] = true
					self:Damage(candidate, damage, "Special", nil, false)
					BloodShared.Heal(entity, CONTACT_HEAL * affinity)
				end
			end
		end

		-- A hit can end the ability (the user died from a counter): do not re-arm then.
		if self.Run == run then
			task.delay(TICK, step)
		end
	end
	step()
end

-- Forgets the drops and invalidates their pending tick, without touching the visuals.
function Supernova:Reset()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	self.Drops = nil
end

function Supernova:OnInterrupt()
	local hadDrops = self.Active
	self:Reset()
	if hadDrops then
		-- Death or seal: the drops are gone, so the clients drop theirs too.
		self:PlayEffect("BloodSupernova", self.Entity.Root.Position, { Cancel = true })
	end
end

return Supernova
