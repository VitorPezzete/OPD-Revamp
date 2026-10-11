--!strict
--[[
	Sand fruit - Sandstorm (charged): a sand tornado released from the caster that drifts
	toward the aim point, dragging in and shredding whoever it reaches.

	Charge: 25 per second held, 4 to 100 (timed on the server). With a = defense affinity,
	s = defense level / cap and c = charge / 100:
	- the storm starts on the caster and drifts at 5 * a studs per second, in a straight
	  line in 3D, along the direction from the caster's right arm to the aim point (the
	  legacy server always measured from the right arm, whichever hand charged): aimed at
	  someone in the air it climbs to them, aimed at the ground nearby it sinks;
	- it lasts clamp(7 * a * c, 2, 14) seconds and reaches clamp(30 * c, 10, 30) studs;
	- every 0.5 s everyone inside (crew mates too, who take no damage) takes
	  150 * a * s Special plus a random floor(50 * a * s) .. floor(75 * a * s) Bleed, not
	  dodgeable, is tied to the storm and is flagged "SandInSandstorm" for 1 second;
	- distances are measured from the centre of the victim's root to the storm's pull
	  point, 3.33 studs above its centre (the "OffPoint" of the legacy model);
	- cooldown: defense level / 250 seconds (see below);
	- pressing grounds the Sand flight for 3 seconds.

	"SandInSandstorm" is the legacy `InSandstorm` flag, whose purpose was to stop Shave
	(the dash) from escaping the pull. The legacy Shave script tested
	`character:FindFirstChild("InSandstorm")` - whether the BoolValue existed, and it
	existed in every character - instead of its Value, so the check blocked Shave for
	everybody, always. Shave is not ported yet: it must refuse to start while
	`entity:HasStatus("SandInSandstorm")` (replicated, so its client can gate too).

	The pull. The legacy storm tied each victim to its pull point with an invisible
	1 stud RopeConstraint for 3 seconds (never refreshed while the rope existed, and
	only players got the InSandstorm flag): whoever it reached was dragged along until
	it ended. There are no server constraints here. A player victim gets the replicated
	"SandRoped" status for those 3 seconds ("<x>|<y>|<z>|<vx>|<vy>|<vz>|<server time>":
	the path of the pull point) and its own client builds the rope
	(Effects.Status.SandRoped); like the legacy rope it is not renewed while it lasts,
	and the next tick ties the victim again if it is still inside. NPCs are simulated
	here: on every tick they are carried (a held push, until the next tick) toward the
	pull point fast enough to reach it by then, on top of the storm's own drift.

	Legacy problems fixed here:
	- One `while` loop per storm walked every player and every enemy twice a second and
	  created attachments and ropes on the server. It is one bounded chain of delayed
	  sphere queries now.
	- The client cooldown was `wait(defense level / 10 * charge / 100)` evaluated after
	  the charge had been reset to 4, i.e. always level / 250 seconds. That effective
	  value is kept (the written formula would give up to 50 s) and enforced here.
	- Charge, affinity and charging flags were script-level values shared by both slots.

	KeepThroughStun: a storm already released keeps going when its caster is stunned, as
	in the legacy game. A release while stunned is dropped.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local EFFECT = "SandSandstorm"
local DAMAGE_TAG = "SandSandstorm"
-- Replicated while charging: "<R or L>|<colors>", the hand holding the small tornado.
local CHARGE_STATUS = "SandCharging"
local IN_STORM_STATUS = "SandInSandstorm"
local IN_STORM_SECONDS = 1
local ROPE_STATUS = "SandRoped"
local ROPE_SECONDS = 3
local STUN_STATUS = "Stunned"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local COOLDOWN_LEVELS_PER_SECOND = 250

local DRIFT_SPEED = 5
local DURATION = 7
local DURATION_MIN = 2
local DURATION_MAX = 14
local RADIUS = 30
local RADIUS_MIN = 10
local PULL_POINT_HEIGHT = 3.33

local TICK_INTERVAL = 0.5
local DAMAGE = 150
local BLEED_MIN = 50
local BLEED_MAX = 75
local PULL_MAX_SPEED = 80
-- Force of the push that stands in for the rope on NPCs, per unit of mass.
local PULL_FORCE = 1e5

type Storm = {
	Start: number,
	-- The pull point when the storm starts.
	Origin: Vector3,
	Velocity: Vector3,
	Duration: number,
	Radius: number,
	Damage: number,
	BleedMin: number,
	BleedMax: number,
	-- Value of the SandRoped status of this storm's victims.
	Rope: string,
}

local Sandstorm = Ability.extend()

Sandstorm.KeepThroughStun = true

-- One damage / pull tick; reschedules itself until the storm is over.
local function blow(self: any, storm: Storm, epoch: number)
	local entity = self.Entity
	if (self.Epoch or 0) ~= epoch or entity.Dead then
		return
	end

	local elapsed = os.clock() - storm.Start
	if elapsed >= storm.Duration then
		return
	end

	local center = storm.Origin + storm.Velocity * elapsed
	for _, target in Hitbox.Sphere(center, storm.Radius, entity) do
		-- Legacy measured to the centre of the root, with no margin for the body.
		if (target.Root.Position - center).Magnitude > storm.Radius then
			continue
		end
		self:Damage(target, storm.Damage, "Special", DAMAGE_TAG, false)
		local bleed = math.random(storm.BleedMin, storm.BleedMax)
		if bleed > 0 then
			self:Damage(target, bleed, "Bleed", DAMAGE_TAG, false)
		end
		if target.Dead then
			continue
		end

		target:SetStatus(IN_STORM_STATUS, true, IN_STORM_SECONDS, true)

		if target.Player then
			if not target:HasStatus(ROPE_STATUS) then
				target:SetStatus(ROPE_STATUS, storm.Rope, ROPE_SECONDS, true)
				self.Roped[target] = storm.Rope
			end
			continue
		end

		local pull = (center - target.Root.Position) / TICK_INTERVAL
		if pull.Magnitude > PULL_MAX_SPEED then
			pull = pull.Unit * PULL_MAX_SPEED
		end
		local force = PULL_FORCE * target.Root.AssemblyMass
		self:Impulse(target, pull + storm.Velocity, TICK_INTERVAL, Vector3.new(force, force, force))
	end

	task.delay(TICK_INTERVAL, blow, self, storm, epoch)
end

function Sandstorm:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function Sandstorm:OnBegin()
	local entity = self.Entity

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	self.Charging = true
	-- The hands alternate from one storm to the next.
	self.RightHand = not self.RightHand
	entity:SetStatus(CHARGE_STATUS, `{if self.RightHand then "R" else "L"}|{self:GetColorString()}`, nil, true)
end

function Sandstorm:OnEnd(input: Ability.AbilityInput)
	local entity = self.Entity
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if self.Charging then
		self.Charging = false
		entity:ClearStatus(CHARGE_STATUS)
	end
	if not charge or entity:HasStatus(STUN_STATUS) then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local scale = affinity * self:GetLevelScale("Defense")
	local percent = charge / CHARGE_MAX
	local cooldown = self:GetLevel("Defense") / COOLDOWN_LEVELS_PER_SECOND
	self.ReadyAt = os.clock() + cooldown
	self:StartCooldown(cooldown)

	local hand = Shared.LimbPosition(entity, "Right Arm")
	local direction = input.AimPosition - hand
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end

	local origin = entity.Root.Position
	local pullPoint = origin + Vector3.new(0, PULL_POINT_HEIGHT, 0)
	local velocity = direction.Unit * DRIFT_SPEED * affinity
	local storm: Storm = {
		Start = os.clock(),
		Origin = pullPoint,
		Velocity = velocity,
		Duration = math.clamp(DURATION * affinity * percent, DURATION_MIN, DURATION_MAX),
		Radius = math.clamp(RADIUS * percent, RADIUS_MIN, RADIUS),
		Damage = DAMAGE * scale,
		BleedMin = math.floor(BLEED_MIN * scale),
		BleedMax = math.floor(BLEED_MAX * scale),
		Rope = string.format(
			"%.2f|%.2f|%.2f|%.3f|%.3f|%.3f|%.3f",
			pullPoint.X,
			pullPoint.Y,
			pullPoint.Z,
			velocity.X,
			velocity.Y,
			velocity.Z,
			Workspace:GetServerTimeNow()
		),
	}
	if not self.Roped then
		-- Victim -> rope value. Weak keys: victims that leave are forgotten on their own.
		self.Roped = setmetatable({}, { __mode = "k" })
	end

	self:PlayEffect(EFFECT, origin, {
		Velocity = velocity,
		Duration = storm.Duration,
		-- Particle size and lifetime scale with affinity * charge, like the legacy storm.
		Power = affinity * percent,
		RightHand = self.RightHand == true,
	})

	-- The legacy loop hit on the frame of the release.
	blow(self, storm, self.Epoch or 0)
end

function Sandstorm:OnInterrupt()
	self.ChargeStart = nil
	if self.Charging then
		self.Charging = false
		self.Entity:ClearStatus(CHARGE_STATUS)
	end
	-- Storms already released stop with their caster (legacy: destroyed with the character),
	-- and let go of whoever they still hold.
	self.Epoch = (self.Epoch or 0) + 1
	if self.Roped then
		for target, rope in self.Roped do
			if target:GetStatus(ROPE_STATUS) == rope then
				target:ClearStatus(ROPE_STATUS)
			end
		end
		table.clear(self.Roped)
	end
end

return Sandstorm
