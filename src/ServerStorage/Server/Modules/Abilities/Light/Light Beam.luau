--!strict
--[[
	Light fruit - Light Beam (held): a continuous laser from the hand to the aim point.

	While the key is held, with a = sniper affinity and s = sniper level / cap:
	- the beam reaches level * a studs and stops at the first thing it touches;
	- six times a second (TICK) everyone within the spark at its end (diameter
	  2.5 * s * a) takes 100 * s * a, "Special", not dodgeable; armament haki doubles it
	  and makes it "Haki". That is the legacy pace: the client sent an update every 5th
	  rendered frame (12 a second at the 60 fps the game ran at) and the server dropped
	  those less than 0.1 s after the last one it took, i.e. every other one;
	- releasing the key ends it; 1.65 s (0.15 + 1.5) before it can be used again.

	It cannot be started while Sacred Jewels is firing or Barrier Body is on, and blocks
	Light Blast.

	Aim: the owner's client streams its aim point as phase 3 inputs ten times a second
	(Effects.Status.LightBeam -> OnAction). The beam leaves the tip of the right arm
	pointed at the aim (shoulder socket + 2 studs along the aim), as the legacy client
	computed it. An aim that arrives when a tick is due is
	resolved at once, so the damage follows the hand of the player instead of waiting for
	a timer; the timer only fills in when the stream is late, and ends the beam if no aim
	arrives for AIM_TIMEOUT seconds. The ray, the hit and the damage are all resolved
	here.

	Visual: every client draws the beam itself, every frame (Effects.Status.LightBeam).
	The owner draws it from its own aim; everyone else from the end point of the last
	tick, replicated as the "LightBeamEnd" attribute. The status value is
	"<fruit slot>;<ability slot>;<range>;<spark diameter>;<colors>".

	Legacy problems fixed here:
	- The client sent the hit position and the server damaged around it: a player could
	  burn anyone anywhere. The beam length sent as `mousehit` was used unchecked too.
	- The updates were "every 5th rendered frame" of the caster against a 0.1 s server
	  debounce, so the damage rate changed with the caster's frame rate (6 a second at
	  60 fps, up to 10 on a fast machine); it is the 60 fps rate for everyone.
	- The beam was a server part resized ten times a second.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local STATUS = Shared.BEAM_STATUS
local END_STATUS = "LightBeamEnd"
local BARRIER_STATUS = "BarrierBody"

local BASE_DAMAGE = 100
local SPARK_DIAMETER = 2.5
local TICK = 1 / 6
-- Legacy shoulder attachment on the torso (half its width, a quarter of its height) and
-- length of the arm.
local SHOULDER_OFFSET = Vector3.new(1, 0.5, 0)
local ARM_LENGTH = 2
-- An aim arriving this much before a tick is due is resolved as that tick.
local EARLY = 0.03
-- A tick this late is resolved by the timer with the aim already held.
local LATE = 0.04
local WATCH_INTERVAL = TICK / 2
local COOLDOWN = 1.65
local AIM_TIMEOUT = 1

local LightBeam = Ability.extend()

function LightBeam:CanBegin(): boolean
	local entity = self.Entity
	return not self.Active
		and os.clock() >= (self.ReadyAt or 0)
		and not entity:HasStatus(Shared.JEWELS_STATUS)
		and not entity:HasStatus(BARRIER_STATUS)
end

-- One damage tick at the aim the server holds right now.
local function resolve(self: any, now: number)
	-- One tick per TICK on average, however the aims arrive: the schedule keeps its own
	-- pace (aims come ten times a second, ticks six) and only restarts from now when it
	-- fell a whole tick behind.
	self.NextTick = (if self.NextTick < now - TICK then now else self.NextTick) + TICK

	local entity = self.Entity
	local affinity = self:GetAffinity("Sniper")
	local scale = self:GetLevelScale("Sniper")
	local shoulder = entity.Root.CFrame:PointToWorldSpace(SHOULDER_OFFSET)
	local origin = shoulder + Shared.Direction(entity, shoulder, self.Aim) * ARM_LENGTH
	local direction = Shared.Direction(entity, origin, self.Aim)

	local hitPosition = Shared.Cast(entity, origin, direction, self:GetLevel("Sniper") * affinity)

	entity:SetStatus(END_STATUS, hitPosition, nil, true)

	local damage, trait = Shared.Haki(self, BASE_DAMAGE * scale * affinity)
	for _, target in Hitbox.Sphere(hitPosition, SPARK_DIAMETER * scale * affinity / 2, entity) do
		self:Damage(target, damage, trait, nil, false)
	end
end

function LightBeam:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local now = os.clock()
	self.Active = true
	self.Aim = input.AimPosition
	self.AimAt = now
	self.NextTick = now
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local context = self.Context
	local affinity = self:GetAffinity("Sniper")
	entity:SetStatus(
		STATUS,
		string.format(
			"%d;%d;%d;%.2f;%s",
			context.FruitSlot,
			context.Definition.Slot,
			math.floor(self:GetLevel("Sniper") * affinity),
			SPARK_DIAMETER * self:GetLevelScale("Sniper") * affinity,
			self:GetColorString()
		),
		nil,
		true
	)

	resolve(self, now)

	-- Fills in the ticks no aim arrived for, and ends a beam nobody is aiming any more.
	local function watch()
		if self.Run ~= run or not self.Active then
			return
		end
		local time = os.clock()
		if time - self.AimAt > AIM_TIMEOUT then
			self:Stop()
			return
		end
		if time >= self.NextTick + LATE then
			resolve(self, time)
		end
		task.delay(WATCH_INTERVAL, watch)
	end
	task.delay(WATCH_INTERVAL, watch)
end

-- Aim stream of the owner's client.
function LightBeam:OnAction(input: Ability.AbilityInput)
	local now = os.clock()
	self.Aim = input.AimPosition
	self.AimAt = now
	if now >= self.NextTick - EARLY then
		resolve(self, now)
	end
end

function LightBeam:Stop()
	if self.Active then
		self.ReadyAt = os.clock() + COOLDOWN
		self:StartCooldown(COOLDOWN)
	end
	self:OnInterrupt()
end

function LightBeam:OnEnd()
	self:Stop()
end

function LightBeam:OnInterrupt()
	self.Active = false
	-- Invalidates the pending watch of the run that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
	self.Entity:ClearStatus(END_STATUS)
end

return LightBeam
