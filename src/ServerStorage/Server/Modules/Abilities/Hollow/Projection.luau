--!strict
--[[
	Hollow fruit - Projection (toggle): the soul leaves the body as a flying ghost the
	player controls, while the real body stays rooted (and vulnerable) where it was.

	Ghost speed:  25 * (2 + defense level / 200) * defense affinity studs per second
	              (the legacy momentum of (2 + level / 200) * affinity per frame with
	              0.96 damping, at its 60 fps terminal speed)
	Contact:      a character the ghost passes through becomes Negative for
	              5 * defense affinity seconds (20 s cooldown per victim), unless the
	              ghost is faded (see Fade)

	Server model - no second character exists (the legacy cloned a full R6 rig, gave
	its network ownership to the client and used Touched on every part of it):
	- the ghost is one position, "HollowGhost" (replicated Vector3 status);
	- the owner's client flies a local ghost model and reports where it is eight times
	  a second as this ability's secondary input (phase 3, the aim point IS the ghost
	  position); every report is checked against the ghost speed and the maximum
	  distance from the body, and refused otherwise;
	- contact is a swept sphere between two accepted reports.
	Everyone draws the ghost from "HollowGhost" in Effects.Status.HollowProjecting.

	Status "HollowProjecting": "<fruit slot>|<ability slot>|<speed>|<range>|<colors>".

	Differences from the legacy, on purpose:
	- The ghost cannot go further than 600 studs from the body (it was unlimited, and
	  the client owned it: it could be teleported anywhere).
	- A stun, seal or death of the real body ends the projection (it used to leave the
	  ghost flying around a dead body until respawn).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local HollowNegative = require(script.Parent.HollowNegative)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = HollowNegative.ProjectingStatus
local GHOST_STATUS = HollowNegative.GhostStatus
local FADED_STATUS = HollowNegative.FadedStatus

local MAX_RANGE = 600
local START_OFFSET = CFrame.new(0, 2, 0)
local MIN_REPORT_INTERVAL = 0.1
-- Reports may be late or bunched: allow a quarter more than the speed, plus a margin.
local SPEED_TOLERANCE = 1.25
-- The camera pitch adds a climb on top of the horizontal speed: up to sqrt(2) in all.
local CLIMB_FACTOR = 1.42
local DISTANCE_MARGIN = 8
local CONTACT_RADIUS = 3
-- Same value as Hitbox: characters are spheres of this radius around their root.
local BODY_RADIUS = 2.5
local STUN_SECONDS = 5

local function sweep(from: Vector3, to: Vector3, exclude: CharacterEntity): { CharacterEntity }
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	local result: { CharacterEntity } = {}

	for _, target in Hitbox.Sphere((from + to) / 2, segment.Magnitude / 2 + CONTACT_RADIUS, exclude) do
		local position = target.Root.Position
		local along = if lengthSquared > 1e-4 then math.clamp((position - from):Dot(segment) / lengthSquared, 0, 1) else 0
		if (from + segment * along - position).Magnitude <= CONTACT_RADIUS + BODY_RADIUS then
			table.insert(result, target)
		end
	end
	return result
end

local Projection = Ability.extend()

-- The legacy client locked the key for half a second after each toggle.
Projection.Debounce = 0.5

function Projection:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	local context = self.Context
	local affinity = self:GetAffinity("Defense")
	local start = (entity.Root.CFrame * START_OFFSET).Position

	self.Active = true
	self.Speed = 25 * (2 + self:GetLevel("Defense") / 200) * affinity
	self.StunTime = STUN_SECONDS * affinity
	self.GhostPosition = start
	self.LastReport = os.clock()

	entity:SetRooted(STATUS, true)
	-- The position first: the effect reads it as soon as the projecting status arrives.
	entity:SetStatus(GHOST_STATUS, start, nil, true)
	entity:SetStatus(
		STATUS,
		string.format("%d|%d|%.2f|%d|%s", context.FruitSlot, context.Definition.Slot, self.Speed, MAX_RANGE, self:GetColorString()),
		nil,
		true
	)
end

-- A position report from the owner's client.
function Projection:OnAction(input: Ability.AbilityInput)
	local entity = self.Entity
	local now = os.clock()
	local elapsed = now - self.LastReport
	if elapsed < MIN_REPORT_INTERVAL then
		return
	end

	local position = input.AimPosition
	local previous: Vector3 = self.GhostPosition
	if (position - entity.Root.Position).Magnitude > MAX_RANGE + DISTANCE_MARGIN then
		return
	end
	-- A refused report does not move LastReport, so an honest client that lagged is
	-- accepted again as soon as enough time has passed for the distance it covered.
	if (position - previous).Magnitude > self.Speed * CLIMB_FACTOR * elapsed * SPEED_TOLERANCE + DISTANCE_MARGIN then
		return
	end

	self.LastReport = now
	self.GhostPosition = position
	entity:SetStatus(GHOST_STATUS, position, nil, true)

	if entity:HasStatus(FADED_STATUS) then
		return
	end
	for _, target in sweep(previous, position, entity) do
		HollowNegative.Apply(self.Services.Status, target, self.StunTime)
	end
end

function Projection:OnInterrupt()
	self.Active = false
	local entity = self.Entity
	entity:SetRooted(STATUS, false)
	entity:ClearStatus(STATUS)
	entity:ClearStatus(GHOST_STATUS)
	entity:ClearStatus(FADED_STATUS)
end

return Projection
