--!strict
--[[
	Chop fruit - Chop Pursuit: the right arm detaches holding blades and chases the
	aimed character for 10 seconds, cutting whenever it is close.

	Arm speed:  60 * sword affinity studs per second, re-aimed every 0.5 s (so it
	            overshoots and swings back, as it always did); 1 * sword affinity once
	            it is within 5 studs
	Damage:     sword level / 4 * sword affinity every 0.2 s while within 5 studs of the
	            target (Sword; doubled and Haki when armament was on as the arm left -
	            it is read once, at the cast, as in the legacy game; not dodgeable)

	Same design as Chop Choke: the arm is a point simulated ten times a second for the
	10 seconds it lasts, drawn by Effects.OneShot.ChopPursuit, with the real arm hidden
	by Effects.Status.ChopPursuit. "Within 5 studs" is tested against the whole stretch
	flown during a tick: the legacy check ran every frame, and at 60 to 120 studs per
	second a tenth of a second is longer than the 10 stud window the arm flies through.
	An arm already sent keeps chasing when its user is stunned (KeepThroughStun), as in
	the legacy game.

	Legacy problems fixed here:
	- The client sent the part under its mouse as the target.
	- The hit cooldown and the "arm in use" flag were shared script globals, and the
	  10 s cleanup ran even after the arm had already been removed and re-cast, cutting
	  the new chase short.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "ChopPursuit"
local HAKI_STATUS = "Haki"
local STUN_STATUS = "Stunned"

local AIM_RADIUS = 4
local CHASE_SPEED = 60
local CLOSE_SPEED = 1
local HIT_DISTANCE = 5
local DURATION = 10
local TICK = 0.1
-- In ticks: the arm re-aims every 0.5 s and cuts every 0.2 s.
local STEER_TICKS = 5
local HIT_TICKS = 2

local function isGone(target: CharacterEntity): boolean
	return target.Dead or not target.Spawned or target.Model.Parent == nil
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

local ChopPursuit = Ability.extend()

ChopPursuit.KeepThroughStun = true

function ChopPursuit:CanBegin(): boolean
	return not self.Active and not self.Entity:HasStatus(STUN_STATUS)
end

function ChopPursuit:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local aimed = Hitbox.Closest(Hitbox.Sphere(input.AimPosition, AIM_RADIUS, entity), input.AimPosition)
	if not aimed then
		return
	end
	local target: CharacterEntity = aimed

	local affinity = self:GetAffinity("Sword")
	local damage = self:GetLevel("Sword") / 4 * affinity
	local trait = "Sword"
	if entity:HasStatus(HAKI_STATUS) then
		damage *= 2
		trait = "Haki"
	end

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(STATUS, true, nil, true)
	self:PlayEffect("ChopPursuit", entity.Root.Position, {
		Target = target.Model,
		ChaseSpeed = CHASE_SPEED * affinity,
		CloseSpeed = CLOSE_SPEED * affinity,
	})

	local position = entity.Root.Position
	local velocity = Vector3.zero
	local ticks = 0
	local lastHitTick = -HIT_TICKS
	local lastTick = DURATION / TICK

	local function step()
		if self.Run ~= run then
			return
		end
		if isGone(target) or ticks >= lastTick then
			self:OnInterrupt()
			return
		end

		local previous = position
		position += velocity * TICK
		local targetPosition = target.Root.Position
		local offset = targetPosition - position
		local close = offset.Magnitude < HIT_DISTANCE
		local passed = close or distanceToSegment(targetPosition, previous, position) < HIT_DISTANCE

		if passed and ticks - lastHitTick >= HIT_TICKS then
			lastHitTick = ticks
			self:Damage(target, damage, trait, nil, false)
		end

		if ticks % STEER_TICKS == 0 and offset.Magnitude > 0.001 then
			velocity = offset.Unit * (if close then CLOSE_SPEED else CHASE_SPEED) * affinity
		end

		ticks += 1
		task.delay(TICK, step)
	end
	step()
end

function ChopPursuit:OnInterrupt()
	self.Active = false
	-- Invalidates the pending step of the arm that was out.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return ChopPursuit
