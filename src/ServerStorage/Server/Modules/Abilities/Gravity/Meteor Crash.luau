--!strict
--[[
	Gravity fruit - Meteor Crash (charged): a meteor is pulled out of the sky onto the
	targeted point.

	Charge: 25 per second held, 4 to 300 (timed on the server); c = charge / 300.
	With n = sniper affinity:
	- the meteor is 100 * n * c studs wide and appears 1000 studs above the user (within
	  100 studs per axis); it takes 10 s to reach the targeted point, accelerating;
	- the impact hits everyone within 200 * n * c studs of that point for
	  10000 * (defense level / cap) * n * c, Special, not dodgeable. The damage really
	  scales with the *defense* level in the legacy script; kept.
	- 20 s cooldown from the release; the release lands a flying user.

	Targeted point. As in the legacy game it is not the point under the cursor itself but
	the first thing met on the line from 1000 studs above the user to that point: the
	meteor comes from the sky, so it lands on a roof, not under it. One server raycast per
	cast. While the key is held the replicated status GravityMeteorAiming (value: fruit
	colors) lets the owner's client show that point (Effects.Status.GravityMeteorAiming:
	the legacy targeting dot and pole).

	Once released the meteor is on its way: interrupting the user (a stun during those
	10 s, a seal) does not call it back, since every client is already showing it fall.
	A dead caster deals no damage (CombatService), so a meteor outliving its caster is
	only a visual. Only the charge itself is undone by OnInterrupt.

	Legacy problems fixed here:
	- The meteor, three explosions and shockwaves were server parts and tweens, and the
	  victims came from GetPartBoundsInRadius.
	- The server had no cooldown beyond 0.25 s: the 20 s were client side only.
	- The impact point came from the client unchecked; it is derived from the validated
	  aim point.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local AURA_SOURCE = "MeteorCrash"
local AIM_STATUS = "GravityMeteorAiming"
local EFFECT = "GravityMeteorCrash"
local DAMAGE_TAG = "GravityMeteorCrash"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 300

local COOLDOWN = 20
local START_SPREAD = 100
local START_HEIGHT = 1000
-- The targeting line starts this far above the user (keep in step with
-- Effects.Status.GravityMeteorAiming).
local SIGHT_HEIGHT = 1000
local FALL_TIME = 10
local METEOR_SIZE = 100
local EXPLOSION_SIZE = 400
local SHOCKWAVE_SIZE = 10
local DAMAGE = 10000
-- A falling meteor is visible from much further than the default effect radius.
local EFFECT_RADIUS = 1500

local random = Random.new()

local MeteorCrash = Ability.extend()

-- First thing on the line from the sky above the user to the aim point, or the aim point.
local function findImpact(entity: CharacterEntity, aim: Vector3): Vector3
	local origin = entity.Root.Position + Vector3.new(0, SIGHT_HEIGHT, 0)
	local offset = aim - origin
	if offset.Magnitude < 1e-3 then
		return aim
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(origin, offset, params)
	return if result then result.Position else aim
end

function MeteorCrash:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function MeteorCrash:OnBegin()
	local colors = self:GetColorString()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	Shared.SetAura(self.Entity, AURA_SOURCE, colors)
	self.Entity:SetStatus(AIM_STATUS, colors, nil, true)
end

function MeteorCrash:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	local entity: CharacterEntity = self.Entity
	Shared.SetAura(entity, AURA_SOURCE, nil)
	entity:ClearStatus(AIM_STATUS)
	if not charge then
		return
	end

	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local power = self:GetAffinity("Sniper") * charge / CHARGE_MAX
	local impact = findImpact(entity, input.AimPosition)
	local explosionSize = EXPLOSION_SIZE * power
	local damage = DAMAGE * self:GetLevelScale("Defense") * power

	self.Services.Effect:Play(EFFECT, impact, {
		Start = entity.Root.Position + Vector3.new(
			random:NextNumber(-START_SPREAD, START_SPREAD),
			START_HEIGHT,
			random:NextNumber(-START_SPREAD, START_SPREAD)
		),
		FallTime = FALL_TIME,
		Size = METEOR_SIZE * power,
		ExplosionSize = explosionSize,
		ShockwaveSize = SHOCKWAVE_SIZE * power,
		Colors = self:GetColorString(),
		Caster = entity.Model,
	}, EFFECT_RADIUS)

	task.delay(FALL_TIME, function()
		if entity.Dead then
			return
		end
		for _, target in Hitbox.Sphere(impact, explosionSize / 2, entity) do
			self:Damage(target, damage, "Special", DAMAGE_TAG, false)
		end
	end)
end

function MeteorCrash:OnInterrupt()
	self.ChargeStart = nil
	Shared.SetAura(self.Entity, AURA_SOURCE, nil)
	self.Entity:ClearStatus(AIM_STATUS)
end

return MeteorCrash
