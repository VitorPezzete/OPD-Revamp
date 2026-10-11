--!strict
--[[
	Snow fruit - Snow Pellet (charged): a snowball that bursts on the first character it
	touches, or after 2 s of flight.

	With c = charge / 100 (charge: 25 per second held, 4 to 100, timed on the server) and
	s = sniper affinity * (sniper level / cap):
	- Ball diameter clamp(10 * s * c, 1, 10), launched at 200 + charge studs per second
	  from the RIGHT arm towards the aim point. The charge ball and the animations
	  alternate hands, right first, but the legacy release message carried the charge
	  where the hand was expected, so the server always threw from the right arm.
	- The legacy ball was a loose part given that velocity once: it falls with gravity
	  all the way. Without haki it did not collide with anything, so it flies through
	  walls and ground (IgnoreWorld) and only reacts to characters. With armament haki it
	  was made solid: it is stopped by the map (the legacy one bounced on; here it stays
	  where it hit) and still only bursts on a character or when its 2 s are up.
	- Touching a character bursts it in a radius of ten ball diameters. After 2 s
	  without touching anyone it bursts where it is, in a radius of ONE diameter (the
	  legacy timeout used the diameter itself as the radius). Both draw the same
	  explosion, ten diameters across.
	- Everyone in the burst takes 1000 * s * c (Special, not dodgeable; doubled and Haki
	  with armament haki) and SnowTouched: 350 * s every 0.5 s, floor(5 * sniper
	  affinity) times.

	The ball is a server-simulated Projectile; clients draw it (Effects.OneShot.SnowPellet)
	and the burst (Effects.OneShot.SnowPelletBurst).

	Stuns do not cancel the charge or the balls in flight (KeepThroughStun), as in the
	legacy game; death, a seal and losing the fruit do.

	Legacy problem fixed here: `if P3Charging == true` compared the BoolValue object, so
	a second "start" was never refused and stacked hand effects and listeners.
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local SnowShared = require(script.Parent.SnowShared)

local STATUS = "SnowPelletCharging"
local EFFECT = "SnowPellet"
local BURST_EFFECT = "SnowPelletBurst"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local BASE_DAMAGE = 1000
local HAKI_MULTIPLIER = 2
local SIZE = 10
local MIN_SIZE = 1
local MAX_SIZE = 10
local BASE_SPEED = 200
local FLIGHT_TIME = 2
-- Burst radius, in ball diameters: on a character, and when the 2 s run out.
local BURST_RADIUS_PER_SIZE = 10
local TIMEOUT_RADIUS_PER_SIZE = 1
-- The explosion drawn is always ten diameters across.
local BURST_VISUAL_PER_SIZE = 10
local DOT_DAMAGE = 350
local DOT_HITS = 5

local SnowPellet = Ability.extend()

SnowPellet.Debounce = 0.1
SnowPellet.KeepThroughStun = true

-- Always the right arm: see the header.
local function getHandPosition(self: any): Vector3
	local arm = self.Entity.Model:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return arm.Position
	end
	return self.Entity.Root.Position
end

function SnowPellet:OnBegin()
	local entity = self.Entity

	if self.ChargeStart then
		return
	end

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	local hand = if self.UseLeft then "Left" else "Right"
	entity:SetStatus(STATUS, string.format("%s|%.2f|%s", hand, self:GetAffinity("Sniper"), self:GetColorString()), nil, true)
end

function SnowPellet:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity

	local origin = getHandPosition(self)
	local hand = if self.UseLeft then "Left" else "Right"
	self.UseLeft = not self.UseLeft
	entity:ClearStatus(STATUS)

	local affinity = self:GetAffinity("Sniper")
	local scale = affinity * self:GetLevelScale("Sniper")
	local chargeScale = charge / 100
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local size = math.clamp(SIZE * scale * chargeScale, MIN_SIZE, MAX_SIZE)
	local speed = BASE_SPEED + charge
	local damage = BASE_DAMAGE * scale * chargeScale * (if haki then HAKI_MULTIPLIER else 1)
	local dotDamage = DOT_DAMAGE * scale
	local dotHits = DOT_HITS * affinity

	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = Projectile.Lead(entity, origin, direction.Unit, speed, speed * FLIGHT_TIME, Workspace.Gravity)

	self.Shots = (self.Shots or 0) + 1
	local id = `{self.Player.UserId}_{self.Shots}`
	local epoch = self.Epoch or 0

	local gravity = Vector3.new(0, -Workspace.Gravity, 0)
	local velocity = direction.Unit * speed
	local burst = false
	-- Where a haki ball was stopped by the map, if it was.
	local stopped: Vector3? = nil

	local function explode(position: Vector3, radius: number)
		if burst then
			return
		end
		burst = true
		-- Balls still in flight when the caster is interrupted fizzle.
		if (self.Epoch or 0) ~= epoch then
			return
		end

		self:PlayEffect(BURST_EFFECT, position, { Id = id, Size = size * BURST_VISUAL_PER_SIZE, Haki = haki })
		for _, target in Hitbox.Sphere(position, radius, entity) do
			self:Damage(target, damage, if haki then "Haki" else "Special", EFFECT, false)
			SnowShared.Touch(self, target, dotDamage, dotHits)
		end
	end

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = speed,
		-- Never the limit: the flight is timed below. This is the most a falling ball covers.
		MaxDistance = (speed + Workspace.Gravity * FLIGHT_TIME) * FLIGHT_TIME,
		Radius = size / 2,
		Owner = entity,
		Gravity = gravity,
		IgnoreWorld = not haki,
		HitOverlapping = true,
		OnHit = function(_target: any, position: Vector3)
			explode(position, size * BURST_RADIUS_PER_SIZE)
		end,
		OnEnd = function(position: Vector3)
			if not burst then
				stopped = position
			end
		end,
	})

	task.delay(FLIGHT_TIME, function()
		local position = stopped or origin + velocity * FLIGHT_TIME + gravity * (FLIGHT_TIME * FLIGHT_TIME / 2)
		explode(position, size * TIMEOUT_RADIUS_PER_SIZE)
	end)

	self:PlayEffect(EFFECT, origin, {
		Id = id,
		Direction = direction,
		Speed = speed,
		Duration = FLIGHT_TIME,
		Gravity = Workspace.Gravity,
		Size = size,
		Haki = haki,
		Hand = hand,
	})
end

function SnowPellet:OnInterrupt()
	self.ChargeStart = nil
	-- Balls still in flight fizzle.
	self.Epoch = (self.Epoch or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return SnowPellet
