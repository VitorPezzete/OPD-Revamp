--!strict
--[[
	Gum fruit - Gum Rocket (Jet Rocket in 2nd Gear): hold to stretch both arms to the aim
	point; release once they have grabbed it to be flung there.

	With L = melee level, m = melee affinity:
	- arm reach      = 2 * L * m studs. A point further away is never grabbed;
	- stretch speed  = (2 + L / 100) studs per frame, (5 + L / 25) in 2nd Gear. The legacy
	  loop ran once per rendered frame; it is taken at 60 frames per second here;
	- flight speed   = 200 + L / 5 * m studs per second, doubled in 2nd Gear, straight at
	  a point 4 studs above the grabbed one, for distance / speed seconds;
	- deploying in 2nd Gear costs 100 health (taken straight from health).
	Unlike the other Jet moves, Jet Rocket has no level gate of its own: the legacy client
	compared its gear, a string, with the number 2, so its "melee 200" check never ran.

	Releasing before the arms arrive just pulls them back, at the speed they went out
	(5 s at most); the move cannot be started again until they are back. Arms sent at a
	point out of reach come back by themselves once they are fully stretched. Jumping
	during the flight ends it (the owner's client reports the jump as the ability's
	secondary input).

	Server / client split. The legacy move was entirely the client's: it picked the
	target, timed the arms, created the BodyVelocity and told the server every frame
	where to draw the arms. Now the server owns target, reach, timing, speed and
	duration, and publishes them in the replicated status

		GumRocket = "<Stretch|Fly>|<x>|<y>|<z>|<speed>|<fruit slot>|<ability slot>"

	(Fly is a timed status lasting exactly the flight). Effects.Status.GumRocket draws
	the arms for everyone and, for the owner, moves the character while the value says
	Fly - the owner simulates its own character, so the velocity has to be applied there.

	Left out: grabbing a moving part (the legacy target followed the part under the
	mouse through an Attachment); the target is the fixed aim point.

	Only something real can be grabbed: there must be a part (map, prop, character),
	terrain or a sword slash in flight (ThrownSlashes) at the aim point. The legacy client took the point under the mouse, which
	with nothing under it was a point far beyond the arms; here an aim into the sky is
	brought back to the aim range, so that point would be an empty spot in mid-air well
	within reach. The arms sent at such a point stretch to it and come back.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local ThrownSlashes = require(ServerStorage.Server.Modules.ThrownSlashes)
local Shared = require(script.Parent._Shared)

local STATUS = "GumRocket"
local LEGACY_FRAME_RATE = 60
local REACH_PER_LEVEL = 2
local FLIGHT_BASE_SPEED = 200
local FLIGHT_LEVEL_DIVISOR = 5
local JET_FLIGHT_MULTIPLIER = 2
local JET_HEALTH_COST = 100
-- The flight aims this far above the grabbed point so the user lands on it.
local TARGET_LIFT = Vector3.new(0, 4, 0)
local MIN_DISTANCE = 2
local MAX_RETRACT_TIME = 5
-- How close to the aim point a surface must be to count as what the hands grab.
local GRAB_RADIUS = 1
local GRAB_PROBE = 2

local GumRocket = Ability.extend()

-- True when there is something to hold at `point`: a part the mouse could have been on
-- (anything solid or visible that is not the user) or terrain.
local function hasSurface(model: Model, from: Vector3, point: Vector3): boolean
	-- A thrown sword slash is something to hold, as the old game's slash part was. It has
	-- no instance here for the queries below to find.
	if ThrownSlashes.IsAt(point, GRAB_RADIUS) then
		return true
	end

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { model }
	for _, part in Workspace:GetPartBoundsInRadius(point, GRAB_RADIUS, overlap) do
		if part.CanCollide or part.Transparency < 1 then
			return true
		end
	end

	-- Terrain is not a part an overlap finds, and a thin edge can sit between two
	-- samples: a short cast through the point, along the line of the arms.
	local offset = point - from
	if offset.Magnitude < 1e-3 then
		return false
	end
	local direction = offset.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	return Workspace:Raycast(point - direction * GRAB_PROBE, direction * GRAB_PROBE * 2, params) ~= nil
end

function GumRocket:CanBegin(): boolean
	return not self.Active
		and not self.Stretching
		and os.clock() >= (self.RetractUntil or 0)
		and not self.Entity.Humanoid.Sit
end

function GumRocket:_publish(phase: string, speed: number, duration: number?)
	local target: Vector3 = self.Target
	local value = string.format(
		"%s|%.1f|%.1f|%.1f|%.1f|%d|%d",
		phase,
		target.X,
		target.Y,
		target.Z,
		speed,
		self.Context.FruitSlot,
		self.Context.Definition.Slot
	)
	self.Entity:SetStatus(STATUS, value, duration, true)
end

function GumRocket:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local level = self:GetLevel("Melee")
	local jet = Shared.IsSecondGear(entity)

	local offset = input.AimPosition - entity.Root.Position
	local distance = offset.Magnitude
	if distance < MIN_DISTANCE then
		return
	end

	if jet then
		entity:TakeDamage(JET_HEALTH_COST)
		if entity.Dead then
			return
		end
	end

	local reach = REACH_PER_LEVEL * level * self:GetAffinity("Melee")
	local stretchSpeed = (if jet then 5 + level / 25 else 2 + level / 100) * LEGACY_FRAME_RATE

	self.Stretching = true
	self.StretchStart = os.clock()
	self.StretchRun = (self.StretchRun or 0) + 1
	if distance <= reach and hasSurface(entity.Model, entity.Root.Position, input.AimPosition) then
		self.Target = input.AimPosition
		self.GrabTime = distance / stretchSpeed
	else
		-- Out of reach, or nothing there to hold: the arms stretch to their limit (or to
		-- the empty point), never grab and come back.
		local length = math.min(distance, reach)
		self.Target = entity.Root.Position + offset.Unit * length
		self.GrabTime = math.huge
		local run = self.StretchRun
		task.delay(length / stretchSpeed, function()
			if self.Stretching and self.StretchRun == run then
				self:_retract()
			end
		end)
	end
	self:_publish("Stretch", stretchSpeed)
end

-- Ends a stretch that grabbed nothing: the arms take as long to come back as they were out.
function GumRocket:_retract()
	self.Stretching = false
	self.RetractUntil = os.clock() + math.min(os.clock() - self.StretchStart, MAX_RETRACT_TIME)
	self.Entity:ClearStatus(STATUS)
end

function GumRocket:OnEnd()
	if not self.Stretching then
		return
	end
	self.Stretching = false

	local entity = self.Entity
	local grabbed = os.clock() - self.StretchStart >= self.GrabTime
	if not grabbed or entity.Humanoid.Sit then
		self:_retract()
		return
	end

	local offset = (self.Target :: Vector3) + TARGET_LIFT - entity.Root.Position
	local distance = offset.Magnitude
	if distance < MIN_DISTANCE then
		entity:ClearStatus(STATUS)
		return
	end

	local speed = FLIGHT_BASE_SPEED + self:GetLevel("Melee") / FLIGHT_LEVEL_DIVISOR * self:GetAffinity("Melee")
	if Shared.IsSecondGear(entity) then
		speed *= JET_FLIGHT_MULTIPLIER
	end
	local duration = distance / speed

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	self:_publish("Fly", speed, duration)

	task.delay(duration, function()
		if self.Run == run then
			self.Active = false
			entity:ClearStatus(STATUS)
		end
	end)
end

-- The owner jumped mid-flight.
function GumRocket:OnAction()
	self:OnInterrupt()
end

function GumRocket:OnInterrupt()
	self.Active = false
	self.Stretching = false
	-- Invalidates the end-of-flight delay of the run that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return GumRocket
