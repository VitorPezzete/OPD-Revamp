--!strict
--[[
	Gravity fruit - Meteor Shower: small meteors rain around the user.

	Fired when the key is released (the legacy client's charge loop was commented out;
	nothing is charged, the ability is only listed as chargeable because of that).
	With n = sniper affinity:
	- floor(10 * n) meteors, one every 0.1 to 0.5 s (random);
	- each one picks a point within 100 studs of the user (per axis) at that moment,
	  finds the ground under it and lands there (+/- 5 studs) one second later;
	- the impact hits everyone within 50 * n studs of that ground point (the blast is
	  centred on it, not on where the meteor itself came down) for
	  600 * (defense level / cap) * n, Special, not dodgeable. The damage really scales
	  with the *defense* level in the legacy script; kept.
	- 10 s cooldown from the release; the release lands a flying user.

	A column with no ground under it (open sea) drops no meteor, as in the legacy game.
	The ground is found with one server raycast per meteor (it decides where the damage
	is, not a visual); clients draw the fall (Effects.OneShot.GravityMeteor).

	As in the legacy game a shower that has started rains to its end whatever happens
	to the user (stun, seal): only death stops the meteors that have not started falling.

	Legacy problems fixed here:
	- The whole shower ran inside the remote handler; meteors, explosions and shockwaves
	  were server parts and tweens, and victims came from GetPartBoundsInRadius.
	- The server had no cooldown at all beyond 0.25 s: the 10 s were client side only.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local RINGS_EFFECT = "GravityRings"
local METEOR_EFFECT = "GravityMeteor"
local DAMAGE_TAG = "GravityMeteorShower"

local COOLDOWN = 10
local METEORS = 10
local SPREAD = 100
local START_SPREAD = 300
local START_HEIGHT = 1000
local GROUND_REACH = 5000
local SCATTER = 5
local FALL_TIME = 1
local MIN_GAP = 0.1
local MAX_GAP = 0.5
local DAMAGE = 600
local EXPLOSION_SIZE = 100
local SHOCKWAVE_SIZE = 4
-- A meteor is visible from much further than the default effect radius.
local EFFECT_RADIUS = 1500

local random = Random.new()

local MeteorShower = Ability.extend()

local function spread(range: number): number
	return random:NextNumber(-range, range)
end

-- Drops one meteor and schedules the next.
local function drop(self: any, epoch: number, remaining: number, affinity: number, damage: number)
	local entity: CharacterEntity = self.Entity
	if (self.Epoch or 0) ~= epoch or remaining <= 0 or entity.Dead then
		return
	end

	local rootPosition = entity.Root.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }

	local column = rootPosition + Vector3.new(spread(SPREAD), START_HEIGHT, spread(SPREAD))
	local ground = Workspace:Raycast(column, Vector3.new(0, -GROUND_REACH, 0), params)
	if ground then
		local impact = ground.Position

		self.Services.Effect:Play(METEOR_EFFECT, impact, {
			Start = rootPosition + Vector3.new(spread(START_SPREAD), START_HEIGHT, spread(START_SPREAD)),
			Landing = impact + Vector3.new(spread(SCATTER), 0, spread(SCATTER)),
			FallTime = FALL_TIME,
			ExplosionSize = EXPLOSION_SIZE * affinity,
			ShockwaveSize = SHOCKWAVE_SIZE * affinity,
			Colors = self:GetColorString(),
			Caster = entity.Model,
		}, EFFECT_RADIUS)

		task.delay(FALL_TIME, function()
			if entity.Dead then
				return
			end
			for _, target in Hitbox.Sphere(impact, EXPLOSION_SIZE * affinity / 2, entity) do
				self:Damage(target, damage, "Special", DAMAGE_TAG, false)
			end
		end)
	end

	task.delay(random:NextNumber(MIN_GAP, MAX_GAP), drop, self, epoch, remaining - 1, affinity, damage)
end

function MeteorShower:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function MeteorShower:OnBegin()
	self.Pressed = true
end

function MeteorShower:OnEnd()
	if not self.Pressed then
		return
	end
	self.Pressed = false

	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Sniper")

	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	self:PlayEffect(RINGS_EFFECT, entity.Root.Position, {})

	self.Epoch = (self.Epoch or 0) + 1
	drop(self, self.Epoch, math.floor(METEORS * affinity), affinity, DAMAGE * self:GetLevelScale("Defense") * affinity)
end

function MeteorShower:OnInterrupt()
	self.Pressed = false
end

return MeteorShower
