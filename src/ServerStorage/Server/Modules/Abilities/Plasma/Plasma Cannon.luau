--!strict
--[[
	Plasma fruit - Plasma Cannon (charged): a volley of plasma rays from a sphere held in
	the left hand, ending with a stronger one.

	Charge: 25 per second held, 4 to 100 (timed on the server).
	With a = sniper affinity and s = sniper level / cap, on release:
	- rays   = floor(floor(sniper level * 0.008) * a * charge / 100 + 1), one every 0.05 s,
	           then one final ray;
	- damage = 250 * s * a * charge / 100 per ray, three times that for the final ray
	           (Special, not dodgeable); doubled and "Haki" with armament haki. The legacy
	           server read the charge clock again for every ray, and that clock was still
	           running: each ray of a volley is worth 1.25 charge more than the previous
	           one (up to the maximum). Same here;
	- each ray goes from the sphere (3 studs below the left arm) to the aim point, at
	  most 250 studs away. It is not stopped by walls (it was not in the legacy game
	  either). The legacy ray was a chain of 5 stud segments, each joint thrown off by up
	  to 2 studs, and the blast sat in the MIDDLE of its last segment: everyone whose root
	  centre is within 5 studs of that point is hit. The same walk is rolled here and the
	  point is sent to the clients for the burst;
	- aim assist, as the legacy client's AimModule ("fov" 1000): at the release the
	  character closest to the line of sight, within min(1000 / (distance along the line
	  + 10), 20) degrees of it, is locked on and every ray of the volley goes to where its
	  root is then. With nobody in the cone the rays go to the aim point of the release.
	The ability cannot be charged again for 1.8 s after a release.

	"PlasmaCharging" (fruit colors) is replicated from the press until the final ray has
	left: the sphere in the hand, the charge clips and the facing. "PlasmaCannonFiring" is
	added for the volley: Effects.Status.PlasmaCharging reads it to switch to the release
	punch.

	What changed from the legacy game:
	- The CLIENT decided how many rays to send and re-sent its mouse position for each
	  one; the count and the 0.05 s spacing are now computed here, and without a locked
	  target the whole volley uses the aim point of the release.
	- The legacy client fired nothing at all (and left the sphere in the hand forever) when
	  floor(sniper level * 0.008) was above 6; with the level cap that cannot happen.
	- The aim assist ran on the client, from the camera; the server measures the same
	  cone from the caster's head (it does not know the camera).
	- The pending rays of a sealed, stunned or dead user are dropped (OnInterrupt).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local CHARGE_STATUS = "PlasmaCharging"
local FIRING_STATUS = "PlasmaCannonFiring"
local EFFECT = "PlasmaCannon"
local DAMAGE_TAG = "PlasmaCannon"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100

local BASE_DAMAGE = 250
local HAKI_MULTIPLIER = 2
local FINAL_MULTIPLIER = 3
local RAYS_PER_LEVEL = 0.008
local RAY_INTERVAL = 0.05
local RAY_RANGE = 250
local HIT_RADIUS = 5
local RECOVERY = 1.8
-- The legacy ray: segments of RAY_STEP studs, each joint off by up to RAY_JITTER whole studs.
local RAY_STEP = 5
local RAY_JITTER = 2
local RAY_MAX_STEPS = 120
-- Legacy aim assist: degrees = min(ASSIST_FOV / (distance along the line + 10), ASSIST_MAX).
local ASSIST_FOV = 1000
local ASSIST_MAX_DEGREES = 20
local ASSIST_MIN_DISTANCE = 0.5

local ARM_NAME = "Left Arm"
local SPHERE_OFFSET = CFrame.new(0, -3, 0)

local PlasmaCannon = Ability.extend()

-- The character the legacy aim assist would have locked on, if any.
local function assisted(entity: any, aim: Vector3): any
	local head = entity.Model:FindFirstChild("Head")
	local eye: Vector3 = if head and head:IsA("BasePart") then head.Position else entity.Root.Position
	local sight = aim - eye
	local reach = sight.Magnitude
	if reach < ASSIST_MIN_DISTANCE then
		return nil
	end
	local direction = sight.Unit

	local best: any = nil
	local bestAngle = ASSIST_MAX_DEGREES
	for _, candidate in Hitbox.Sphere(eye, reach, entity) do
		local offset = candidate.Root.Position - eye
		if offset.Magnitude < 1e-3 then
			continue
		end
		local angle = math.acos(math.clamp(direction:Dot(offset.Unit), -1, 1))
		local along = math.clamp(offset.Magnitude * math.cos(angle), ASSIST_MIN_DISTANCE, reach)
		local degrees = math.deg(angle)
		if degrees <= math.min(ASSIST_FOV / (along + 10), ASSIST_MAX_DEGREES) and degrees < bestAngle then
			best, bestAngle = candidate, degrees
		end
	end
	return best
end

-- Middle of the last segment of a legacy ray from `origin` to `target`: where it bursts.
local function burstPoint(origin: Vector3, target: Vector3): Vector3
	local current = origin
	local steps = 0
	while (target - current).Magnitude > RAY_STEP and steps < RAY_MAX_STEPS do
		local offset = Vector3.new(
			math.random(-RAY_JITTER, RAY_JITTER),
			math.random(-RAY_JITTER, RAY_JITTER),
			math.random(-RAY_JITTER, RAY_JITTER)
		)
		current += (target - current).Unit * RAY_STEP + offset
		steps += 1
	end
	return (current + target) / 2
end

function PlasmaCannon:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function PlasmaCannon:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	self.Entity:SetStatus(CHARGE_STATUS, self:GetColorString(), nil, true)
end

function PlasmaCannon:OnEnd(input: Ability.AbilityInput)
	local began: number? = self.ChargeStart
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge or not began then
		return
	end

	local entity = self.Entity
	local affinity = self:GetAffinity("Sniper")
	local scale = self:GetLevelScale("Sniper")
	local percent = charge / CHARGE_MAX
	local aim = input.AimPosition

	local rays = math.floor(math.floor(self:GetLevel("Sniper") * RAYS_PER_LEVEL) * affinity * percent + 1)
	local locked = assisted(entity, aim)

	self.ReadyAt = os.clock() + RECOVERY
	self:StartCooldown(RECOVERY)
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	entity:SetStatus(FIRING_STATUS, true, nil, true)

	local function fire(final: boolean)
		if self.Run ~= run or entity.Dead then
			return
		end

		local arm = entity.Model:FindFirstChild(ARM_NAME)
		local origin = if arm and arm:IsA("BasePart") then (arm.CFrame * SPHERE_OFFSET).Position else entity.Root.Position
		local goal = if locked and not locked.Dead and locked.Model.Parent then locked.Root.Position else aim
		local offset = goal - origin
		local target = if offset.Magnitude > RAY_RANGE then origin + offset.Unit * RAY_RANGE else goal
		local burst = burstPoint(origin, target)

		-- The charge clock is still running, as it was on the legacy server.
		local running = math.floor(math.clamp((os.clock() - began) * CHARGE_RATE, CHARGE_MIN, CHARGE_MAX))
		local damage = BASE_DAMAGE * scale * affinity * running / CHARGE_MAX
		if final then
			damage *= FINAL_MULTIPLIER
		end
		local trait: CombatTypes.DamageTrait = "Special"
		local haki = self.Services.Haki:IsArmamentActive(entity)
		if haki then
			damage *= HAKI_MULTIPLIER
			trait = "Haki"
		end

		self:PlayEffect(EFFECT, origin, {
			Target = target,
			Burst = burst,
			Haki = haki,
			Size = affinity,
			Thickness = math.clamp(scale, 0.5, 1),
		})

		for _, victim in Hitbox.Sphere(burst, HIT_RADIUS, entity) do
			-- Legacy measured to the centre of the root, with no margin for the body.
			if (victim.Root.Position - burst).Magnitude <= HIT_RADIUS then
				self:Damage(victim, damage, trait, DAMAGE_TAG, false)
			end
		end

		if final then
			-- The sphere stays in the hand until the last ray has left it.
			entity:ClearStatus(CHARGE_STATUS)
			entity:ClearStatus(FIRING_STATUS)
		end
	end

	-- Bounded volley: at most floor(cap * 0.008) * 2 + 1 rays plus the final one.
	for index = 1, rays do
		task.delay((index - 1) * RAY_INTERVAL, fire, false)
	end
	task.delay(rays * RAY_INTERVAL, fire, true)
end

function PlasmaCannon:OnInterrupt()
	self.ChargeStart = nil
	-- Drops the rays of a volley still on its way out.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(CHARGE_STATUS)
	self.Entity:ClearStatus(FIRING_STATUS)
end

return PlasmaCannon
