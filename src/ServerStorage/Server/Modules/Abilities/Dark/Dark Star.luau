--!strict
--[[
	Dark fruit - Dark Star (charged): a star of darkness leaves the hand and drags
	everyone who was standing next to the user along with it.

	Charge: 25 per second held, 4 to 100 (timed on the server); c = charge / 100.
	With n = sniper affinity and s = sniper level / cap:
	- the star flies from the right hand towards the aim point at 200 studs per second
	  (never downwards: a descending aim is flattened) for
	  hold = clamp(2.5 * s * n * c, 1, 5) seconds;
	- everyone within 35 * n * s studs of the hand at release is tied to the star and
	  takes 200 * n * s * c, Special, not dodgeable, ten times (every hold / 10 s).
	  Players are also stunned for `hold`; NPCs are not, as in the legacy game: they are
	  dragged but keep acting;
	- cooldown 15 - sniper level / 100 seconds from the release. It cannot be charged
	  while another Dark power is "recent" (DarkRecent, see _Shared), and the other Dark
	  powers cannot be used while it is being charged.

	While charging, the DarkStarCharging status ("<preview scale>|<colors>|<hand>") shows
	the star in the hand; its owner also sees the sphere the star will grab from, scaled
	as the legacy client did (sniper level / 15 * n). The charging hand and the
	animations alternate, right first, as the legacy client did; the star always leaves
	from the right arm (the legacy release never told the server which hand).

	Players simulate their own character, so the victim's client follows the star
	(Effects.Status.DarkStarHeld, which gets the path); NPCs are carried along it here by
	held pushes renewed ten times a second.

	KeepThroughStun: a star already released keeps flying, holding and hurting when its
	caster is stunned, as in the legacy game. A press or a release while stunned is
	dropped. Death, a seal and losing the fruit let its victims go.

	Legacy problems fixed here:
	- The star was an unanchored server part with a BodyVelocity and victims were tied
	  to it with server RopeConstraints.
	- The client could send the charge and the hand; both are decided here.
	The star does not stop at walls on the server (the legacy part could get stuck).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local CHARGE_STATUS = Shared.StarChargingStatus
local HELD_STATUS = "DarkStarHeld"
local EFFECT = "DarkStar"
local DAMAGE_TAG = "DarkStar"
local STUN = "DarkStar"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100

local SPEED = 200
local PULL_RADIUS = 35
local HOLD_TIME = 2.5
local HOLD_MIN = 1
local HOLD_MAX = 5
local DAMAGE = 200
local TICKS = 10
local BASE_COOLDOWN = 15
local COOLDOWN_LEVELS_PER_SECOND = 100
-- Sniper levels per unit of scale of the range sphere the charging user sees.
local PREVIEW_LEVELS_PER_SCALE = 15
-- How hard an NPC is steered back onto the star's path, per stud of error.
local NPC_CORRECTION = 2
local NPC_STEP = 0.1
-- NPCs are carried with a mover no NPC can resist, like the rope to the star.
local NPC_FORCE = Vector3.new(1e6, 1e6, 1e6)

type Cast = {
	Start: number,
	Duration: number,
	Origin: Vector3,
	Direction: Vector3,
	Targets: { CharacterEntity },
	Npcs: { CharacterEntity },
	Damage: number,
	Interval: number,
}

local DarkStar = Ability.extend()

DarkStar.KeepThroughStun = true

local function pulse(self: any, cast: Cast, epoch: number, remaining: number)
	if (self.Epoch or 0) ~= epoch then
		return
	end

	for _, target in cast.Targets do
		if not target.Dead then
			self:Damage(target, cast.Damage, "Special", DAMAGE_TAG, false)
		end
	end

	if remaining > 1 then
		task.delay(cast.Interval, pulse, self, cast, epoch, remaining - 1)
	else
		self.Cast = nil
	end
end

-- Keeps the NPCs on the star (the server simulates them); ends with the flight.
local function drag(self: any, cast: Cast, epoch: number)
	local elapsed = os.clock() - cast.Start
	if (self.Epoch or 0) ~= epoch or elapsed >= cast.Duration then
		return
	end

	local star = cast.Origin + cast.Direction * SPEED * elapsed
	for _, target in cast.Npcs do
		if not target.Dead then
			self:Impulse(target, cast.Direction * SPEED + (star - target.Root.Position) * NPC_CORRECTION, NPC_STEP, NPC_FORCE)
		end
	end
	task.delay(NPC_STEP, drag, self, cast, epoch)
end

function DarkStar:CanBegin(): boolean
	local entity = self.Entity
	return os.clock() >= (self.ReadyAt or 0)
		and not entity:HasStatus(Shared.RecentStatus)
		and not entity:HasStatus(Shared.StunStatus)
end

function DarkStar:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	local previewScale = self:GetLevel("Sniper") / PREVIEW_LEVELS_PER_SCALE * self:GetAffinity("Sniper")
	local hand = if self.LeftHand then "Left" else "Right"
	self.Entity:SetStatus(CHARGE_STATUS, string.format("%.2f|%s|%s", previewScale, self:GetColorString(), hand), nil, true)
end

function DarkStar:OnEnd(input: Ability.AbilityInput)
	local entity: CharacterEntity = self.Entity
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	entity:ClearStatus(CHARGE_STATUS)
	if not charge or entity:HasStatus(Shared.StunStatus) then
		return
	end

	local affinity = self:GetAffinity("Sniper")
	local scale = affinity * self:GetLevelScale("Sniper")
	local percent = charge / CHARGE_MAX

	-- The next charge uses the other hand.
	local hand = if self.LeftHand then "Left" else "Right"
	self.LeftHand = not self.LeftHand

	local cooldown = BASE_COOLDOWN - self:GetLevel("Sniper") / COOLDOWN_LEVELS_PER_SECOND
	self.ReadyAt = os.clock() + cooldown
	self:StartCooldown(cooldown)

	local arm = entity.Model:FindFirstChild("Right Arm")
	local origin = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Y < 0 then
		direction = Vector3.new(direction.X, 0, direction.Z)
	end
	if direction.Magnitude < 0.05 then
		local look = entity.Root.CFrame.LookVector
		direction = Vector3.new(look.X, 0, look.Z)
	end
	direction = direction.Unit

	local holdTime = math.clamp(HOLD_TIME * scale * percent, HOLD_MIN, HOLD_MAX)

	-- A previous star is always over by now (the cooldown is longer than the hold).
	self:OnInterrupt()

	local targets = Hitbox.Sphere(origin, PULL_RADIUS * scale - Shared.BodyRadius, entity)
	local npcs: { CharacterEntity } = {}
	for _, target in targets do
		if not target.Player then
			table.insert(npcs, target)
		end
	end

	local cast: Cast = {
		Start = os.clock(),
		Duration = holdTime,
		Origin = origin,
		Direction = direction,
		Targets = targets,
		Npcs = npcs,
		Damage = DAMAGE * scale * percent,
		Interval = holdTime / TICKS,
	}
	self.Cast = cast

	self:PlayEffect(EFFECT, origin, { Direction = direction, Speed = SPEED, Duration = holdTime, Hand = hand })

	local path = string.format(
		"%.1f|%.1f|%.1f|%.3f|%.3f|%.3f|%d|%.2f",
		origin.X,
		origin.Y,
		origin.Z,
		direction.X,
		direction.Y,
		direction.Z,
		SPEED,
		holdTime
	)
	for _, target in cast.Targets do
		if target.Player then
			self.Services.Status:ApplyStun(target, holdTime, STUN)
			target:SetStatus(HELD_STATUS, path, holdTime, true)
		end
	end

	local epoch = self.Epoch or 0
	pulse(self, cast, epoch, TICKS)
	if #npcs > 0 then
		drag(self, cast, epoch)
	end
end

function DarkStar:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
	self.Epoch = (self.Epoch or 0) + 1

	-- Let go of whoever is still tied to the star.
	local cast: Cast? = self.Cast
	self.Cast = nil
	if cast then
		for _, target in cast.Targets do
			self.Services.Status:Clear(target, STUN)
			target:ClearStatus(HELD_STATUS)
		end
	end
end

return DarkStar
