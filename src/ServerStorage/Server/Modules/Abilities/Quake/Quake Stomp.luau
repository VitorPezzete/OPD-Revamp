--!strict
--[[
	Quake fruit - Quake Stomp (charged): a stomp sends a shock ball into the ground under
	the caster; where it lands the ground shatters, rocks jut out in a ring and everyone
	around is hurt and thrown away.

	Charge: 50 per second, 4 to 60 (timed on the server, from the rounded start the legacy
	server used - see _Shared). The kick takes 0.2 s (right leg) or 0.25 s (left leg)
	after the release and counts as charge, as it did in the legacy game (the client only
	told the server once the kick had landed). With a = defense affinity,
	s = defense level / cap and c = charge / 60:
	- the ball starts 5 studs under the caster's root and falls at 200 studs per second
	  to the ground under the caster's right arm (the legacy server always measured from
	  the right arm: the "hand" argument it received was the charge). Nothing happens if
	  there is no ground within 1000 studs;
	- on landing everyone within charge * a studs takes 1600 * a * s * c, Special, not
	  dodgeable; armament haki at the kick doubles it and makes it Haki;
	- hurt or not, they are carried away from the landing point, slightly upward, at
	  250 * a^2 * s * charge / 100 studs per second for 0.18 s (the legacy BodyVelocity:
	  MaxForce 1e5 per unit of mass on every axis, P 1250) and lose their footing
	  (PlatformStand) for as long;
	- 1 s cooldown from the kick (1.2 / 1.25 s from the release), during which no other
	  Quake power can be started either.

	While charging, a quake bubble grows on the stomping foot (Effects.Status.
	QuakeCharging), to a mesh scale of 20 * s * a over three seconds - the formula of the
	Tsunami's bubbles, the other Defense power. It is NOT in the dumped legacy scripts,
	whose stomp branch prepares a color and a limb and creates nothing: restored at the
	owner's request (he remembers the ball on the foot). BUBBLE_SCALE = 0 removes it.

	Legacy problems fixed here:
	- The landing loop ran once per rock (16 to 23 times) and queried every part within
	  the radius each time; only the first pass could hit anyone.
	- The ball and the rocks were server parts moved by server tweens, and the landing
	  was triggered by `Tween.Completed`. It is one delayed sphere query now.
	- The charge sent by the client was ignored but the affinity and charge were
	  script-level variables shared by both fruit slots.
	- The knockback was a BodyVelocity plus PlatformStand written by the server on
	  characters it does not simulate. Same mover and same PlatformStand now, created by
	  whoever simulates the character (Effects.Status.QuakeStomped for players).
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local EFFECT = "QuakeStomp"
local DAMAGE_TAG = "QuakeStomp"

local CHARGE_RATE = 50
local CHARGE_MIN = 4
local CHARGE_MAX = 60
-- Seconds between the release and the kick landing.
local WINDUP_RIGHT = 0.2
local WINDUP_LEFT = 0.25
local COOLDOWN = 1

-- Mesh scale the bubble on the foot reaches, per unit of level scale and affinity.
local BUBBLE_SCALE = 20

local BALL_OFFSET = 5
local BALL_SPEED = 200
local GROUND_RAY = 1000
local DAMAGE = 1600
local KNOCKBACK = 250
local KNOCKBACK_CHARGE = 100
local KNOCKBACK_LIFT = 0.25
local KNOCKBACK_SECONDS = 0.18
-- MaxForce of the legacy mover on each axis, per unit of mass of the target.
local KNOCKBACK_FORCE = 1e5
local KNOCKBACK_POWER = 1250
-- Replicated for KNOCKBACK_SECONDS: the owning client drops the character (PlatformStand).
local STOMPED_STATUS = "QuakeStomped"

type Landing = {
	Ground: Vector3,
	Radius: number,
	Damage: number,
	Trait: CombatTypes.DamageTrait,
	Push: number,
}

local QuakeStomp = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
QuakeStomp.DamageStyle = "Plain"

local function land(self: any, landing: Landing, epoch: number)
	local entity = self.Entity
	if (self.Epoch or 0) ~= epoch or entity.Dead then
		return
	end

	for _, target in Hitbox.Sphere(landing.Ground, landing.Radius, entity) do
		self:Damage(target, landing.Damage, landing.Trait, DAMAGE_TAG, false)
		if target.Dead then
			continue
		end

		-- As in the legacy game: the flat part of the 3D direction, plus a fixed lift.
		local away = target.Root.Position - landing.Ground
		local direction = Vector3.yAxis
		if away.Magnitude > 0.01 then
			local unit = away.Unit
			direction = Vector3.new(unit.X, KNOCKBACK_LIFT, unit.Z).Unit
		end
		local force = KNOCKBACK_FORCE * target.Root.AssemblyMass
		self:Impulse(
			target,
			direction * landing.Push,
			KNOCKBACK_SECONDS,
			Vector3.new(force, force, force),
			KNOCKBACK_POWER
		)
		if target.Player then
			target:SetStatus(STOMPED_STATUS, true, KNOCKBACK_SECONDS, true)
		else
			-- NPCs are simulated here. Never put back what was found: found limp (another
			-- throw in progress), that would leave the NPC limp for good.
			local humanoid = target.Humanoid
			humanoid.PlatformStand = true
			task.delay(KNOCKBACK_SECONDS, function()
				if humanoid.Parent then
					humanoid.PlatformStand = false
				end
			end)
		end
	end
end

-- The kick lands: the ball leaves from under the caster.
local function kick(self: any, charge: number, epoch: number)
	local entity = self.Entity
	if (self.Epoch or 0) ~= epoch or entity.Dead then
		return
	end

	local arm = Shared.LimbPosition(entity, "Right Arm")
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(arm, Vector3.new(0, -GROUND_RAY, 0), params)
	if not result then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local levelScale = self:GetLevelScale("Defense")
	local percent = charge / CHARGE_MAX
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local start = entity.Root.Position - Vector3.new(0, BALL_OFFSET, 0)
	local landing: Landing = {
		Ground = result.Position,
		Radius = charge * affinity,
		Damage = DAMAGE * affinity * levelScale * percent * (if haki then Shared.HAKI_MULTIPLIER else 1),
		Trait = if haki then "Haki" else "Special",
		Push = KNOCKBACK * affinity ^ 2 * levelScale * charge / KNOCKBACK_CHARGE,
	}
	local fallTime = (landing.Ground - start).Magnitude / BALL_SPEED

	self:PlayEffect(EFFECT, start, {
		Ground = landing.Ground,
		FallTime = fallTime,
		Charge = charge,
		Percent = percent,
		Affinity = affinity,
		LevelScale = levelScale,
		Haki = haki,
	})

	task.delay(fallTime, land, self, landing, epoch)
end

function QuakeStomp:CanBegin(): boolean
	return Shared.CanCharge(self)
end

function QuakeStomp:OnBegin()
	-- The kick is part of the charge: the bar is full that much earlier.
	local bubble = BUBBLE_SCALE * self:GetLevelScale("Defense") * self:GetAffinity("Defense")
	Shared.BeginCharge(self, "Stomp", bubble, CHARGE_MAX / CHARGE_RATE - WINDUP_RIGHT)
end

function QuakeStomp:OnEnd()
	local windup = if self.RightSide then WINDUP_RIGHT else WINDUP_LEFT
	local charge = Shared.EndCharge(self, CHARGE_RATE, CHARGE_MIN, CHARGE_MAX, windup)
	if not charge then
		return
	end

	self.ReadyAt = os.clock() + windup + COOLDOWN
	self:StartCooldown(windup + COOLDOWN)
	self.Entity:SetStatus(Shared.STOMP_LOCK_STATUS, true, windup + COOLDOWN)

	Shared.Swing(self, "Stomp")
	task.delay(windup, kick, self, charge, self.Epoch or 0)
end

function QuakeStomp:OnInterrupt()
	Shared.CancelCharge(self)
	-- A kick still winding up or a ball still falling does nothing.
	self.Epoch = (self.Epoch or 0) + 1
end

return QuakeStomp
