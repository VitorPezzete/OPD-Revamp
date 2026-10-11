--!strict
--[[
	Quake fruit - Seismic Wave (charged): a punch cracks the air and a shock bubble bursts
	at the aim point, slamming everyone inside toward the ground.

	Charge: 50 per second held, 8 to 100 (timed on the server, from the rounded start the
	legacy server used - see _Shared). With a = sniper affinity,
	L = sniper level, s = L / cap and c = charge / 100:
	- bubble factor k = (1.5 * max(charge, 25) + 1) / 10 * 0.004 * L * a; the blast is a
	  cube of 4 * k studs centred on the aim point (about 120 studs at level 500,
	  affinity 1 and a full charge), turned like the legacy mouse.Hit: facing along the
	  line of sight (taken here from the caster's head to the aim point);
	- everyone inside, crew mates included, is stunned for 0.25 s, driven straight down at
	  125 * a * s * c studs per second for 0.25 s (the legacy BodyVelocity: MaxForce 1e7
	  per unit of mass on every axis, P 1250), and takes 2100 * c * a * s * f, Special, not dodgeable, where
	  f = clamp(1 - 0.9 * distance / (2 * k), 0.1, 1) fades with the distance to the
	  centre. Armament haki doubles the damage but, as in the legacy game, it stays
	  Special;
	- 1 s cooldown from the release.

	Differences with the legacy game:
	- Range: the legacy server accepted aim points up to 2000 studs away; the framework
	  rejects inputs further than AbilityConfig.MaxAimDistance (1000).
	- The legacy client sent mouse.Target and the server did nothing when it was nil
	  (aiming at the sky). The server no longer receives parts from the client, so any
	  valid aim point works.
	- Seated targets were made to jump before the knock down; they are unseated instead.

	Legacy problems fixed here:
	- The remote's arguments were swapped (the "hit" argument was the part and the
	  "target" argument the CFrame) and both came from the client unchecked.
	- The hit list came from GetPartBoundsInBox over every part in up to 240 studs.
	- The server tweened the bubble and yielded the remote handler on it.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local EFFECT = "QuakeSeismic"
local DAMAGE_TAG = "QuakeSeismic"
local STUN_NAME = "QuakeSeismic"

local CHARGE_RATE = 50
local CHARGE_MIN = 8
local CHARGE_MAX = 100
local COOLDOWN = 1

local SIZE_MIN_CHARGE = 25
local SIZE_PER_CHARGE = 1.5
local SIZE_PER_LEVEL = 0.004
local CUBE_PER_FACTOR = 4
-- Bubble on the hand while charging grows to 20 * s * a (mesh scale).
local BUBBLE_SCALE = 20

local DAMAGE = 2100
local FALLOFF = 0.9
local FALLOFF_MIN = 0.1
local STUN_SECONDS = 0.25
local SLAM_SPEED = 125
local SLAM_SECONDS = 0.25
-- MaxForce of the legacy mover on each axis, per unit of mass of the target.
local SLAM_FORCE = 1e7
local SLAM_POWER = 1250
-- Extra distance at which clients still receive the effect, past the caster.
local EFFECT_MARGIN = 400

local SeismicWave = Ability.extend()
-- Legacy accepted aim points this far away.
SeismicWave.MaxAimDistance = 2000

function SeismicWave:CanBegin(): boolean
	return Shared.CanCharge(self)
end

function SeismicWave:OnBegin()
	local bubble = BUBBLE_SCALE * self:GetLevelScale("Sniper") * self:GetAffinity("Sniper")
	Shared.BeginCharge(self, "Seismic", bubble, CHARGE_MAX / CHARGE_RATE)
end

function SeismicWave:OnEnd(input: Ability.AbilityInput)
	local entity = self.Entity
	local charge = Shared.EndCharge(self, CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	Shared.Swing(self, "Seismic")

	local affinity = self:GetAffinity("Sniper")
	local levelScale = self:GetLevelScale("Sniper")
	local percent = charge / CHARGE_MAX
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local factor = (SIZE_PER_CHARGE * math.max(charge, SIZE_MIN_CHARGE) + 1) / 10
		* SIZE_PER_LEVEL
		* self:GetLevel("Sniper")
		* affinity
	local side = CUBE_PER_FACTOR * factor
	local center = input.AimPosition

	local damage = DAMAGE * percent * affinity * levelScale * (if haki then Shared.HAKI_MULTIPLIER else 1)
	local slam = Vector3.new(0, -SLAM_SPEED * affinity * levelScale * percent, 0)
	local status = self.Services.Status

	-- The legacy box was the camera-aligned CFrame of mouse.Hit.
	local head = Shared.LimbPosition(entity, "Head")
	local sight = center - head
	local box = if sight.Magnitude > 0.5 then CFrame.lookAt(center, center + sight) else CFrame.new(center)

	if side > 0 then
		for _, target in Hitbox.Box(box, Vector3.new(side, side, side), entity) do
			local distance = (target.Root.Position - center).Magnitude
			local falloff = math.clamp(1 - distance / (2 * factor) * FALLOFF, FALLOFF_MIN, 1)

			status:ApplyStun(target, STUN_SECONDS, STUN_NAME)
			if target.Humanoid.Sit then
				target.Humanoid.Sit = false
			end
			local force = SLAM_FORCE * target.Root.AssemblyMass
			self:Impulse(target, slam, SLAM_SECONDS, Vector3.new(force, force, force), SLAM_POWER)
			self:Damage(target, damage * falloff, "Special", DAMAGE_TAG, false)
		end
	end

	-- Not self:PlayEffect: the blast can be far from the caster, who must still receive it
	-- (the crack at the fist is part of the same effect).
	local reach = (center - entity.Root.Position).Magnitude + EFFECT_MARGIN
	self.Services.Effect:Play(EFFECT, center, {
		Size = side,
		Force = factor / 5,
		RightHand = self.RightSide == true,
		Haki = haki,
		Colors = self:GetColorString(),
		Caster = entity.Model,
	}, reach)
end

function SeismicWave:OnInterrupt()
	Shared.CancelCharge(self)
end

return SeismicWave
