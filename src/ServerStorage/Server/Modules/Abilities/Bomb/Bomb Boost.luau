--!strict
--[[
	Bomb fruit - Bomb Boost (charged): the feet detonate and throw the user towards the
	aim point, hurting whoever stands next to the blast.

	Charge: 34 per second held, 4 to 100 (timed on the server).
	With m = melee affinity, s = melee level / cap, c = charge / 100:
	- blast diameter = 200 * m * s * c around the right leg; a second ball is drawn on
	  the left leg but, as in the legacy game, only the right one is tested;
	- damage = 1000 * m * s * c, Special, not dodgeable; doubled with armament haki;
	- launch speed = melee level / (3 - m) * c + 50 * m studs per second towards the aim
	  point, held for a tenth of a second: the legacy BodyVelocity (MaxForce 4,000,000
	  on every axis, default P, destroyed after 0.1 s), applied through the framework's
	  held push. The replicated BombBoost status "<vx>|<vy>|<vz>|<cast number>" only
	  turns the owner towards the throw (Effects.Status.BombBoost).

	Legacy problems fixed here:
	- The launch was a client BodyVelocity whose speed used the CLIENT's charge value; the
	  server now computes it from its own timer.
	- The client skipped the launch for a handful of stuns it knew about; a stunned or
	  sealed user never gets here now (the charge is interrupted), and a rooted or seated
	  one still explodes but is not thrown.

	The launch formula has two copies in the decompiled client (+100 * m and +50 * m);
	only the +50 * m branch is reachable, so that is the one used.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local CHARGE_RATE = 34
local GROW_SECONDS = 3
local DIAMETER = 200
local DAMAGE = 1000
local LAUNCH_AFFINITY_SPEED = 50
local LEG = "Right Leg"
local OTHER_LEG = "Left Leg"
local LAUNCH_SECONDS = 0.1
local LAUNCH_FORCE = Vector3.new(4000000, 4000000, 4000000)
local LAUNCH_STATUS = "BombBoost"
local LAUNCH_STATUS_SECONDS = 0.5

local BombBoost = Ability.extend()

function BombBoost:CanBegin(): boolean
	return not Shared.IsCharging(self.Entity)
end

function BombBoost:OnBegin()
	Shared.BeginCharge(self, "Boost", "Melee", GROW_SECONDS, Shared.ChargeMax / CHARGE_RATE)
end

function BombBoost:OnEnd(input: Ability.AbilityInput)
	local charge = Shared.EndCharge(self, CHARGE_RATE)
	if not charge then
		return
	end

	local entity = self.Entity
	local affinity = self:GetAffinity("Melee")
	local percent = charge / Shared.ChargeMax
	local power = affinity * self:GetLevelScale("Melee") * percent
	local diameter = DIAMETER * power
	local damage = DAMAGE * power
	local haki = self.Services.Haki:IsArmamentActive(entity)
	if haki then
		damage *= Shared.HakiMultiplier
	end

	local ball = { Scale = diameter, PartSize = Shared.BallPartSize }
	Shared.Explode(self, Shared.LimbPosition(entity, LEG), diameter / 2, damage, haki, 0, "Power5", nil, ball)
	-- The left leg's ball: drawn only.
	self:PlayEffect(Shared.Effect, Shared.LimbPosition(entity, OTHER_LEG), {
		Radius = diameter / 2,
		Haki = haki,
		Blend = 0,
		Template = "Power5",
		Scale = diameter,
		PartSize = Shared.BallPartSize,
	})

	if entity.Humanoid.Sit or entity:IsRooted() then
		return
	end
	-- Affinity is 1 to 2, so the divisor stays between 1 and 2.
	local speed = self:GetLevel("Melee") / math.max(3 - affinity, 1) * percent + LAUNCH_AFFINITY_SPEED * affinity
	local velocity = Shared.AimDirection(entity, input.AimPosition) * speed
	self.Launches = (self.Launches or 0) + 1
	entity:SetStatus(
		LAUNCH_STATUS,
		string.format("%.1f|%.1f|%.1f|%d", velocity.X, velocity.Y, velocity.Z, self.Launches),
		LAUNCH_STATUS_SECONDS,
		true
	)
	self:Impulse(entity, velocity, LAUNCH_SECONDS, LAUNCH_FORCE)
end

function BombBoost:OnInterrupt()
	Shared.CancelCharge(self)
end

return BombBoost
