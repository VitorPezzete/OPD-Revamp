--!strict
--[[
	Chop fruit - Chop Choke: the left arm detaches, homes on the aimed character's head
	and grabs it.

	Arm speed:  50 * SWORD affinity studs per second, homing (the legacy script read the
	            sword affinity here, and the legacy numbers are the specification)
	Damage:     melee level, once, when the arm gets within 5 studs (Special, not dodgeable)
	After the hit the arm holds on for 2 s and is back 1 s later; an arm that never
	arrives is recalled after 15 s. Only one arm can be out at a time.

	The grab is a choke hold: the legacy arm was welded to the victim's head with a
	BodyPosition (MaxForce 1e6 on every axis) fixed where the head was, which pinned the
	victim on the spot, in the air too, for the 2 s it held. That is a held push of zero
	velocity with the same force here. A caster petrified by Love (LoveStunned) loses an
	arm still in flight, and an arm that lands then lets go at once.

	The arm is not an instance on the server: it is a point advanced towards the target
	ten times a second for at most 15 s. Clients draw it (Effects.OneShot.ChopChoke) and
	hide the real arm while the status is set (Effects.Status.ChopChoke). An arm already
	sent keeps going when its user is stunned (KeepThroughStun), as in the legacy game.

	Legacy problems fixed here:
	- The client sent the part under its mouse as the target. The server now picks the
	  character closest to the validated aim point.
	- The arm was a server part with a BodyVelocity, steered by a Heartbeat connection
	  that was never disconnected when the target left or despawned (the arm then hung
	  in the air until the 15 s cleanup). The arm is recalled at once in that case, and
	  everything ends in OnInterrupt.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "ChopChoke"
local STUN_STATUS = "Stunned"
local LOVE_STATUS = "LoveStunned"

-- How far from the aim point a character may be and still count as "aimed at".
local AIM_RADIUS = 4
local BASE_SPEED = 50
local HIT_DISTANCE = 5
local HOLD_SECONDS = 2
-- The BodyPosition that held the grabbed head in place.
local HOLD_FORCE = Vector3.new(1e6, 1e6, 1e6)
local RECOVER_SECONDS = 1
local TIMEOUT = 15
local TICK = 0.1

local function getHeadPosition(target: CharacterEntity): Vector3
	local head = target.Model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head.Position else target.Root.Position
end

local function isGone(target: CharacterEntity): boolean
	return target.Dead or not target.Spawned or target.Model.Parent == nil
end

local ChopChoke = Ability.extend()

-- An arm already sent keeps going when its user is stunned, as in the legacy game; a
-- stunned user cannot send one.
ChopChoke.KeepThroughStun = true

function ChopChoke:CanBegin(): boolean
	return not self.Active and not self.Entity:HasStatus(STUN_STATUS)
end

function ChopChoke:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local aimed = Hitbox.Closest(Hitbox.Sphere(input.AimPosition, AIM_RADIUS, entity), input.AimPosition)
	if not aimed then
		return
	end
	local target: CharacterEntity = aimed

	local speed = BASE_SPEED * self:GetAffinity("Sword")

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(STATUS, true, nil, true)
	self:PlayEffect("ChopChoke", entity.Root.Position, { Target = target.Model, Speed = speed })

	local position = entity.Root.Position
	local deadline = os.clock() + TIMEOUT

	local function step()
		if self.Run ~= run then
			return
		end
		if isGone(target) or os.clock() >= deadline or entity:HasStatus(LOVE_STATUS) then
			self:OnInterrupt()
			return
		end

		local offset = getHeadPosition(target) - position
		local travel = speed * TICK
		if offset.Magnitude - travel > HIT_DISTANCE then
			position += offset.Unit * travel
			task.delay(TICK, step)
			return
		end

		self:Damage(target, self:GetLevel("Melee"), "Special", nil, false)
		local hold = if entity:HasStatus(LOVE_STATUS) then 0 else HOLD_SECONDS
		if hold > 0 and not isGone(target) then
			self:Impulse(target, Vector3.zero, hold, HOLD_FORCE)
		end
		task.delay(hold + RECOVER_SECONDS, function()
			if self.Run == run then
				self:OnInterrupt()
			end
		end)
	end
	step()
end

function ChopChoke:OnInterrupt()
	self.Active = false
	-- Invalidates the pending step / release of the arm that was out.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return ChopChoke
