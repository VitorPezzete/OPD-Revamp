--!strict
--[[
	Gravity fruit - Crushing Force (charged): gravity multiplies around the user,
	slamming everyone nearby into the ground and holding them there.

	Charge: 40 per second held, 4 to 300 (timed on the server); c = charge / 300.
	With d = defense affinity, L = defense level and s = L / cap:
	- area: a cylinder around the user, radius 1.25 * B and half height 0.25 * B, where
	  B = (L * 0.1 * d + 50) * c;
	- everyone in it is stunned for t1 = 1.5 * d * c seconds, thrown down at
	  200 * d * c studs per second for 0.18 s (the legacy BodyVelocity: MaxForce
	  1e5 * the victim's mass on each axis, P 1250), laid flat ("GravityCrushed") and takes
	  50 * s * c * d, Special, not dodgeable, N times, every t1 / 20 s, where
	  N = clamp(floor(20 * c), 2, 20);
	- halfway through t1, whoever is within 20 studs of the ground is pinned: stunned for
	  t2 = 3 * d * c seconds more and takes 125 * s * c * d another N times, every
	  t2 / 20 s. Those still in the air get up when t1 ends.
	- 10 s cooldown from the release; the press and the release both land a flying user.

	Players lie flat through the replicated GravityCrushed status (their own client sets
	PlatformStand, Effects.Status.GravityCrushed); NPCs are simulated here, so their
	PlatformStand is set here for the same time.

	As in the legacy game a cast that has landed runs to its end whatever happens to the
	user (stun, seal): only the charge is undone by OnInterrupt. Victims are let go by
	the timers of their own stun and status.

	While the key is held the replicated status GravityCrushCharging
	("<B at full charge>|<seconds to full charge>|<colors>") lets the owner's client draw
	the area growing around the user (Effects.Status.GravityCrushCharging), as the legacy
	client did from its own charge counter.

	Legacy problems fixed here:
	- Each victim got a server BodyVelocity and two spawned damage loops; it is one
	  bounded chain per phase for the whole cast now.
	- PlatformStand was set by the server and only reset by a delay of the same script:
	  a victim whose attacker left stayed on the floor.
	- Victims were found with GetPartBoundsInBox over the whole map.
	At a tiny charge the legacy ticks were one frame apart; they are at least
	MIN_INTERVAL apart here.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local AURA_SOURCE = "Crush"
local CHARGE_STATUS = "GravityCrushCharging"
local CRUSHED_STATUS = "GravityCrushed"
local EFFECT = "GravityCrush"
local DAMAGE_TAG = "GravityCrush"
local STUN = "GravityCrush"

local CHARGE_RATE = 40
local CHARGE_MIN = 4
local CHARGE_MAX = 300
-- The legacy client filled its charge bar and its ring at 37.5 per second (8 s to the
-- top) while the server counted 40: what the user sees keeps the client's pace.
local DISPLAY_SECONDS = 300 / 37.5

local COOLDOWN = 10
local BASE_SIZE = 50
local SIZE_PER_LEVEL = 0.1
local RADIUS_FACTOR = 1.25
local HALF_HEIGHT_FACTOR = 0.25
local SLAM_SPEED = 200
local SLAM_TIME = 0.18
local SLAM_FORCE_PER_MASS = 1e5
local SLAM_POWER = 1250
local AIR_STUN = 1.5
local AIR_DAMAGE = 50
local GROUND_STUN = 3
local GROUND_DAMAGE = 125
local GROUND_REACH = 20
local MAX_TICKS = 20
local MIN_TICKS = 2
local MIN_INTERVAL = 0.03
local SHOCKWAVE_SIZE = 4.5
local SHOCKWAVE_OFFSET = Vector3.new(0, -1, 0)

local CrushingForce = Ability.extend()

-- One damage tick for every listed victim; reschedules itself `remaining` times in all.
local function press(self: any, epoch: number, targets: { CharacterEntity }, damage: number, remaining: number, interval: number)
	if (self.Epoch or 0) ~= epoch then
		return
	end

	for _, target in targets do
		if not target.Dead then
			self:Damage(target, damage, "Special", DAMAGE_TAG, false)
		end
	end

	if remaining > 1 then
		task.delay(interval, press, self, epoch, targets, damage, remaining - 1, interval)
	end
end

local function isNearGround(target: CharacterEntity): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { target.Model }
	return Workspace:Raycast(target.Root.Position, Vector3.new(0, -GROUND_REACH, 0), params) ~= nil
end

-- Lays the target flat for `duration`. A player's client does it from the status.
local function flatten(target: CharacterEntity, colors: string, duration: number)
	target:SetStatus(CRUSHED_STATUS, colors, duration, true)
	if target.Player then
		return
	end
	target.Humanoid.PlatformStand = true
	task.delay(duration + 0.05, function()
		if not target:HasStatus(CRUSHED_STATUS) and target.Humanoid.Parent then
			target.Humanoid.PlatformStand = false
		end
	end)
end

function CrushingForce:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function CrushingForce:OnBegin()
	local entity: CharacterEntity = self.Entity
	local colors = self:GetColorString()
	local fullSeconds = DISPLAY_SECONDS
	local fullSize = self:GetLevel("Defense") * SIZE_PER_LEVEL * self:GetAffinity("Defense") + BASE_SIZE

	self:BeginCharge(fullSeconds)
	Shared.SetAura(entity, AURA_SOURCE, colors)
	entity:SetStatus(CHARGE_STATUS, `{math.floor(fullSize * 10) / 10}|{fullSeconds}|{colors}`, nil, true)
end

function CrushingForce:OnEnd()
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	local entity: CharacterEntity = self.Entity
	Shared.SetAura(entity, AURA_SOURCE, nil)
	entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end

	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	-- Lets go of the victims of a previous cast, if any are still held.
	self:Release()
	local epoch: number = self.Epoch

	local percent = charge / CHARGE_MAX
	local affinity = self:GetAffinity("Defense")
	local power = self:GetLevelScale("Defense") * percent * affinity
	local colors = self:GetColorString()
	local center = entity.Root.Position

	local size = (self:GetLevel("Defense") * SIZE_PER_LEVEL * affinity + BASE_SIZE) * percent
	local targets = Hitbox.Cylinder(center, size * RADIUS_FACTOR, size * HALF_HEIGHT_FACTOR, entity)
	self.Targets = targets

	self:PlayEffect(EFFECT, center + SHOCKWAVE_OFFSET, { Size = SHOCKWAVE_SIZE * affinity * percent })

	local ticks = math.clamp(math.floor(MAX_TICKS * percent), MIN_TICKS, MAX_TICKS)
	local airStun = AIR_STUN * affinity * percent
	local groundStun = GROUND_STUN * affinity * percent
	local slam = Vector3.new(0, -SLAM_SPEED * affinity * percent, 0)

	for _, target in targets do
		self.Services.Status:ApplyStun(target, airStun, STUN)
		flatten(target, colors, airStun)
		local force = SLAM_FORCE_PER_MASS * target.Root.AssemblyMass
		self:Impulse(target, slam, SLAM_TIME, Vector3.new(force, force, force), SLAM_POWER)
	end

	press(self, epoch, targets, AIR_DAMAGE * power, ticks, math.max(airStun / MAX_TICKS, MIN_INTERVAL))

	task.delay(airStun / 2, function()
		if self.Epoch ~= epoch then
			return
		end

		local pinned: { CharacterEntity } = {}
		for _, target in targets do
			if not target.Dead and isNearGround(target) then
				self.Services.Status:ApplyStun(target, groundStun, STUN)
				flatten(target, colors, groundStun)
				table.insert(pinned, target)
			end
		end

		-- The legacy loop waited one interval before its first tick.
		local interval = math.max(groundStun / MAX_TICKS, MIN_INTERVAL)
		task.delay(interval, press, self, epoch, pinned, GROUND_DAMAGE * power, ticks, interval)
	end)
end

-- Stops the pending ticks and lets go of everyone still held by the last cast.
function CrushingForce:Release()
	self.Epoch = (self.Epoch or 0) + 1

	local targets: { CharacterEntity }? = self.Targets
	self.Targets = nil
	if targets then
		for _, target in targets do
			self.Services.Status:Clear(target, STUN)
			target:ClearStatus(CRUSHED_STATUS)
			if not target.Player and target.Humanoid.Parent then
				target.Humanoid.PlatformStand = false
			end
		end
	end
end

function CrushingForce:OnInterrupt()
	self.ChargeStart = nil
	Shared.SetAura(self.Entity, AURA_SOURCE, nil)
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return CrushingForce
