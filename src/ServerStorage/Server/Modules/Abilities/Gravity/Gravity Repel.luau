--!strict
--[[
	Gravity fruit - Gravity Repel (charged): the character the user is pointing at is
	flung away from the user.

	Charge: 40 per second held, 4 to 300 (timed on the server); c = charge / 300.
	With n = sniper affinity:
	- the target must be within 30 + sniper level * 0.05 * n studs of the user;
	- it is pushed straight away from the user at 250 * n * (sniper level / cap) * c
	  studs per second, held for 0.25 s (the legacy BodyVelocity lasted that long);
	- it takes 1500 * (defense level / cap) * n * c, Special, not dodgeable. The damage
	  really scales with the *defense* level in the legacy script (the push and the
	  range use sniper); kept.
	- 1 s cooldown from the release; the release lands a flying user.

	Target. The legacy client picked it (AimModule:GetAutoTarget) and the server trusted
	it, only checking the distance: the character closest in angle to the cursor ray,
	within min(1000 / (depth + 10), 20) degrees of it as seen from the camera, depth being
	its distance along the ray (at most the distance of the point under the cursor). So
	the cursor only has to be near the target, not on it. The client only sends an aim
	point now and the same cone is applied here, among the characters in range. The
	camera is not known to the server: it is taken CAMERA_DISTANCE studs behind the user
	on the line to the aim point.

	While the key is held the replicated status GravityRepelCharging ("<range>|<colors>")
	lets the owner's client mark the character the release would hit
	(Effects.Status.GravityRepelCharging, same cone), as the legacy client did.

	Push. The legacy server put a BodyVelocity in the target's root for 0.25 s, with
	MaxForce 1e5 * the target's mass on each axis and P 1250: the same held push is
	applied here (Ability.Impulse), on whoever simulates the target.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local AURA_SOURCE = "Repel"
local DAMAGE_TAG = "GravityRepel"
local CHARGE_STATUS = "GravityRepelCharging"

local CHARGE_RATE = 40
local CHARGE_MIN = 4
local CHARGE_MAX = 300
-- The legacy client filled its charge bar at 37.5 per second while the server counted 40.
local DISPLAY_SECONDS = 300 / 37.5

local COOLDOWN = 1
local BASE_RANGE = 30
local RANGE_PER_LEVEL = 0.05
local PUSH = 250
local PUSH_TIME = 0.25
-- The legacy mover: MaxForce per unit of the target's mass (each axis) and P.
local PUSH_FORCE_PER_MASS = 1e5
local PUSH_POWER = 1250
local DAMAGE = 1500

-- The legacy auto-target cone (keep in step with Effects.Status.GravityRepelCharging).
local AIM_FOV = 1000
local AIM_FOV_PADDING = 10
local AIM_MAX_ANGLE = 20
local AIM_MIN_DEPTH = 0.5
local CAMERA_DISTANCE = 12

local GravityRepel = Ability.extend()

local function getRange(self: any): number
	return BASE_RANGE + self:GetLevel("Sniper") * RANGE_PER_LEVEL * self:GetAffinity("Sniper")
end

local function findTarget(entity: CharacterEntity, aim: Vector3, range: number): CharacterEntity?
	local rootPosition = entity.Root.Position
	local toAim = aim - rootPosition
	if toAim.Magnitude < 1e-3 then
		return nil
	end
	local direction = toAim.Unit
	local eye = rootPosition - direction * CAMERA_DISTANCE
	local aimDepth = toAim.Magnitude + CAMERA_DISTANCE

	local best: CharacterEntity? = nil
	local bestAngle = AIM_MAX_ANGLE
	for _, candidate in Hitbox.Sphere(rootPosition, range, entity) do
		local position = candidate.Root.Position
		-- Hitbox pads its radius with the body; the legacy range was root to root.
		if (position - rootPosition).Magnitude > range then
			continue
		end

		local offset = position - eye
		local cosine = math.clamp(direction:Dot(offset) / offset.Magnitude, -1, 1)
		local angle = math.deg(math.acos(cosine))
		local depth = math.clamp(offset.Magnitude * cosine, AIM_MIN_DEPTH, aimDepth)
		if angle <= AIM_FOV / (depth + AIM_FOV_PADDING) and angle < bestAngle then
			best, bestAngle = candidate, angle
		end
	end
	return best
end

function GravityRepel:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function GravityRepel:OnBegin()
	local entity = self.Entity
	local colors = self:GetColorString()
	self:BeginCharge(DISPLAY_SECONDS)
	Shared.SetAura(entity, AURA_SOURCE, colors)
	entity:SetStatus(CHARGE_STATUS, `{math.floor(getRange(self) * 10) / 10}|{colors}`, nil, true)
end

function GravityRepel:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	local entity: CharacterEntity = self.Entity
	Shared.SetAura(entity, AURA_SOURCE, nil)
	entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end

	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local target = findTarget(entity, input.AimPosition, getRange(self))
	if not target then
		return
	end

	local affinity = self:GetAffinity("Sniper")
	local percent = charge / CHARGE_MAX
	local offset = target.Root.Position - entity.Root.Position
	if offset.Magnitude > 1e-3 then
		local velocity = offset.Unit * PUSH * affinity * self:GetLevelScale("Sniper") * percent
		local force = PUSH_FORCE_PER_MASS * target.Root.AssemblyMass
		self:Impulse(target, velocity, PUSH_TIME, Vector3.new(force, force, force), PUSH_POWER)
	end
	self:Damage(target, DAMAGE * self:GetLevelScale("Defense") * affinity * percent, "Special", DAMAGE_TAG, false)
end

function GravityRepel:OnInterrupt()
	self.ChargeStart = nil
	Shared.SetAura(self.Entity, AURA_SOURCE, nil)
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return GravityRepel
