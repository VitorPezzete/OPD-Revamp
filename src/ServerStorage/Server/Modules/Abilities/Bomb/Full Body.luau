--!strict
--[[
	Bomb fruit - Full Body (charged): self-destruct. The user stands still while the
	whole body charges, then explodes around itself and pays for it with its own health.

	Charge: 10 per second held, 4 to 100 (ten seconds for a full charge, timed on the
	server). While charging the user is rooted and carries the "BombSelfDestruct" status
	(the legacy SelfDestruct flag that Dash, Shave and Shambles refuse to act on).

	With d = defense affinity, s = defense level / cap, c = charge / 100 and
	h = current health / 30000 at release:
	- blast diameter = 1000 * d * s * c * h around the root (root distance; the ball drawn
	  is half that wide, see _Shared);
	- damage         = 15000 * d * c * h, Special, not dodgeable (no haki bonus, and no
	  level term: both as in the legacy game);
	- self damage    = damage * (3 - d), taken straight from health (no mitigation), so a
	  better affinity costs less. It can kill the user.

	Others are damaged before the user pays, so a lethal cost still lands the blast.

	Legacy problems fixed here:
	- The root was "NoWalk until time() + 2000", lifted only by a release that arrived
	  while alive: a charge interrupted by a seal or a stun left the user unable to walk
	  for half an hour, with SelfDestruct stuck on. Root and status are removed in
	  OnInterrupt now.
	- The release handler checked the MELEE level (50) for a Defense 400 ability.
	- The charging rings were server parts created in an unbounded `while Charging` loop.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local STATUS = "BombSelfDestruct"
local ROOT = "BombSelfDestruct"

local CHARGE_RATE = 10
local GROW_SECONDS = 10
local DIAMETER = 1000
local DAMAGE = 15000
local HEALTH_REFERENCE = 30000
-- Self damage = damage * (SELF_COST - defense affinity).
local SELF_COST = 3

local FullBody = Ability.extend()

function FullBody:CanBegin(): boolean
	return not Shared.IsCharging(self.Entity)
end

function FullBody:OnBegin()
	local entity = self.Entity
	Shared.BeginCharge(self, "Full", "Defense", GROW_SECONDS, Shared.ChargeMax / CHARGE_RATE)
	entity:SetRooted(ROOT, true)
	entity:SetStatus(STATUS, true)
	-- The legacy server raised the flight disabler when the charge started and on every
	-- step of it (StartCharge.server 325-338): flights land now, cannot take off during
	-- the charge (rooted) and stay locked for 3 s after it (OnEnd).
	self.Services.Ability:RaiseFlightLock(entity)
end

function FullBody:OnEnd()
	local entity = self.Entity
	if self.Charging then
		self.Services.Ability:RaiseFlightLock(entity)
	end
	local charge = Shared.EndCharge(self, CHARGE_RATE)
	entity:SetRooted(ROOT, false)
	entity:ClearStatus(STATUS)
	if not charge or entity.Dead then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local strength = affinity * (charge / Shared.ChargeMax) * (entity.Health / HEALTH_REFERENCE)
	local diameter = DIAMETER * strength * self:GetLevelScale("Defense")
	local damage = DAMAGE * strength

	Shared.Explode(self, entity.Root.Position, diameter / 2, damage, false, 1, "Power6", nil, {
		Scale = diameter,
		PartSize = Shared.BallPartSize,
	})
	entity:TakeDamage(damage * math.max(SELF_COST - affinity, 0))
end

function FullBody:OnInterrupt()
	-- Only the charge this ability owns holds the root: a release or interrupt of an
	-- idle Full Body must not touch anything.
	if self.Charging then
		self.Entity:SetRooted(ROOT, false)
		self.Entity:ClearStatus(STATUS)
	end
	Shared.CancelCharge(self)
end

return FullBody
