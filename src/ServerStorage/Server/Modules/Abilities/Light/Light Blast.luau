--!strict
--[[
	Light fruit - Light Blast (charged): an instant beam that explodes where it lands.

	Charge: 25 per second held, 4 to 100 (timed on the server). On release, with
	c = charge / 100, a = sniper affinity and s = sniper level / cap:
	- the beam leaves the hand (right and left in turn, as the legacy charge mode did)
	  towards the aim point and reaches level * 2 * a * c studs, stopping at the first
	  thing it touches;
	- everyone whose root is within the explosion (diameter 125 * s * a * c, measured to
	  the centre of the root as the legacy check did) takes 1000 * s * a * c, "Special",
	  not dodgeable; armament haki doubles it and makes it "Haki";
	- 0.5 s between a release and the next charge.

	It cannot be started while Light Beam is firing (the legacy `LightCooldown`).

	Legacy problems fixed here:
	- The release handler never checked that a charge was running: firing the remote
	  directly used whatever start time was stored, i.e. a free full charge.
	- The ray was walked 2 studs at a time in a loop (up to 1000 raycasts per shot).
	- The beam and the explosion were server parts; the blast only looked at models that
	  were direct children of Workspace / Enemies.

	Kept as it was: the charging star is sized with the sniper level but the MELEE
	affinity (45 * s * melee affinity).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local CHARGE_STATUS = "LightBlastCharging"
local EFFECT = "LightBlast"

local CHARGE_RATE = 25
local MIN_CHARGE = 4
local MAX_CHARGE = 100
local BASE_DAMAGE = 1000
local RANGE_PER_LEVEL = 2
local BLAST_DIAMETER = 125
-- Length (X mesh scale) the charging star reaches after 3 s, per s * a.
local STAR_LENGTH = 45
local COOLDOWN = 0.5
-- Hitbox widens every shape by this body allowance; the legacy blast tested the centre
-- of the root, so it is taken back out.
local BODY_RADIUS = 2.5
local EFFECT_RADIUS = 400

local LightBlast = Ability.extend()

function LightBlast:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0) and not self.Entity:HasStatus(Shared.BEAM_STATUS)
end

function LightBlast:OnBegin()
	self:BeginCharge(MAX_CHARGE / CHARGE_RATE)
	self.Charging = true
	local length = STAR_LENGTH * self:GetLevelScale("Sniper") * self:GetAffinity("Melee")
	local hand = if self.Left then "Left" else "Right"
	self.Entity:SetStatus(CHARGE_STATUS, `{string.format("%.2f", length)}|{self:GetColorString()}|{hand}`, nil, true)
	self.Entity:SetStatus(Shared.AIM_STATUS, true, nil, true)
end

function LightBlast:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, MIN_CHARGE, MAX_CHARGE)
	if not charge then
		return
	end
	local entity = self.Entity
	entity:ClearStatus(CHARGE_STATUS)
	entity:ClearStatus(Shared.AIM_STATUS)
	self.Charging = false
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local fraction = charge / 100
	local affinity = self:GetAffinity("Sniper")
	local scale = self:GetLevelScale("Sniper")

	local left: boolean = self.Left == true
	self.Left = not left
	local origin = Shared.HandOrigin(entity, left)
	local direction = Shared.Direction(entity, origin, input.AimPosition)
	local range = self:GetLevel("Sniper") * RANGE_PER_LEVEL * affinity * fraction
	local hitPosition = Shared.Cast(entity, origin, direction, range)

	local radius = BLAST_DIAMETER * scale * affinity * fraction / 2
	local damage, trait, haki = Shared.Haki(self, BASE_DAMAGE * scale * affinity * fraction)

	-- Sent around the caster with a radius that also covers the far end of a long beam.
	self.Services.Effect:Play(EFFECT, origin, {
		To = hitPosition,
		Radius = radius,
		Haki = haki,
		Hand = if left then "Left" else "Right",
		Colors = self:GetColorString(),
		Caster = entity.Model,
	}, EFFECT_RADIUS + (hitPosition - origin).Magnitude)

	for _, target in Hitbox.Sphere(hitPosition, radius - BODY_RADIUS, entity) do
		self:Damage(target, damage, trait, nil, false)
	end
end

function LightBlast:OnInterrupt()
	self.ChargeStart = nil
	-- Only when this ability is the one aiming: OnInterrupt also runs for idle siblings.
	if self.Charging then
		self.Charging = false
		self.Entity:ClearStatus(Shared.AIM_STATUS)
	end
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return LightBlast
