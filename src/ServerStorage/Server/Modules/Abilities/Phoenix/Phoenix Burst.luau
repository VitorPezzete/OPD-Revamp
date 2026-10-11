--!strict
--[[
	Phoenix fruit - Phoenix Burst (charged): a beam of phoenix fire that bursts where it
	lands.

	Charge: 25 per second held, 4 to 100 (timed on the server). c = charge / 100,
	a = sniper affinity, s = sniper level / cap.

	On release the beam leaves 1 stud ahead of the root towards the aim point and stops
	at the first obstacle, 150 studs at most (one ray). It hits instantly, once, everyone
	whose root position is in either box (both square across, long axis on the beam; the
	legacy test was the root's centre, with no margin for the body):
	- along the beam: clamp(25 * c * a, 15, 50) wide, 1.4 * beam length long, centred on
	  the middle of the beam;
	- the burst: clamp(40 * c * a, 15, 100) wide, 5 * clamp(6.096 * c, 3, 12) long,
	  centred 7 studs past the end of the beam.
	Damage: 750 * a^2 * s * c, trait "Melee" (the legacy trait: logia bodies let it
	through); with armament haki 1500 * a^2 * s * c, trait "Haki". Not dodgeable.
	Knockback, hurt or not: carried directly away from the caster (in 3D) at
	250 * a^2 * s * c studs/s for 0.18 s (the legacy BodyVelocity: MaxForce 1e5 per unit
	of mass on every axis, P 1250), with no footing (PlatformStand) for as long.

	Cooldown after a release: 3 / a seconds. It was a wait in the legacy client only (the
	server had a 0.25 s debounce); it is enforced here.

	Charging or releasing lands Fly / Soar and locks them for 3 s (legacy flight
	disabler): done by AbilityService on the press and on the release, see Modules.FlightLock.

	Legacy problems fixed here: the server trusted the client's mouse CFrame, walked the
	ray in 75 steps of 2 studs, created four anchored meshes plus two invisible hitbox
	parts per character tested, and wrote the BodyVelocity and PlatformStand of the
	knockback from the server on characters it does not simulate (same mover now, created
	by whoever simulates the character; Effects.Status.PhoenixBurstHit for players).
]]
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local CHARGE_STATUS = "PhoenixBurstCharging"
local EFFECT = "PhoenixBurst"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local COOLDOWN = 3

local ORIGIN_OFFSET = 1
local MAX_DISTANCE = 150
local DAMAGE = 750
local HAKI_DAMAGE = 1500
local KNOCKBACK = 250
local KNOCKBACK_SECONDS = 0.18
-- MaxForce of the legacy mover on each axis, per unit of mass of the target.
local KNOCKBACK_FORCE = 1e5
local KNOCKBACK_POWER = 1250
-- Replicated for KNOCKBACK_SECONDS: the owning client drops the character (PlatformStand).
local HIT_STATUS = "PhoenixBurstHit"

local BEAM_WIDTH = 25
local BEAM_WIDTH_MIN = 15
local BEAM_WIDTH_MAX = 50
local BEAM_LENGTH_SCALE = 1.4
local BURST_WIDTH = 40
local BURST_WIDTH_MIN = 15
local BURST_WIDTH_MAX = 100
local BURST_THICKNESS = 6.096
local BURST_THICKNESS_MIN = 3
local BURST_THICKNESS_MAX = 12
local BURST_LENGTH_SCALE = 5
local BURST_FORWARD = 7

local PhoenixBurst = Ability.extend()
-- The legacy script dealt this damage without a style: ResistAbilities does not apply.
PhoenixBurst.DamageStyle = "Plain"

-- Characters whose root centre is inside the box (Hitbox.Box adds a body radius).
local function rootsInBox(cframe: CFrame, size: Vector3, exclude: CharacterEntity, into: { [CharacterEntity]: boolean })
	local half = size / 2
	for _, target in Hitbox.Box(cframe, size, exclude) do
		local offset = cframe:PointToObjectSpace(target.Root.Position)
		if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
			into[target] = true
		end
	end
end

function PhoenixBurst:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function PhoenixBurst:OnBegin()
	local entity = self.Entity

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	entity:SetStatus(CHARGE_STATUS, self:GetColorString(), nil, true)
end

function PhoenixBurst:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end

	local entity = self.Entity
	local affinity = self:GetAffinity("Sniper")
	local cooldown = COOLDOWN / math.max(affinity, 0.1)
	self.ReadyAt = os.clock() + cooldown
	self:StartCooldown(cooldown)

	local percent = charge / CHARGE_MAX
	local power = affinity ^ 2 * self:GetLevelScale("Sniper") * percent
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local look = entity.Root.CFrame.LookVector
	local origin = entity.Root.Position + look * ORIGIN_OFFSET
	local offset = input.AimPosition - origin
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else look

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.Model }
	local result = Workspace:Raycast(origin, direction * MAX_DISTANCE, params)
	local distance = if result then result.Distance else MAX_DISTANCE
	local hitPosition = origin + direction * distance

	-- Y axis of the boxes lies on the beam, like the legacy parts.
	local rotation = (CFrame.lookAt(origin, origin + direction) * CFrame.Angles(math.rad(90), 0, 0)).Rotation
	local beamWidth = math.clamp(BEAM_WIDTH * percent * affinity, BEAM_WIDTH_MIN, BEAM_WIDTH_MAX)
	local burstWidth = math.clamp(BURST_WIDTH * percent * affinity, BURST_WIDTH_MIN, BURST_WIDTH_MAX)
	local burstLength = BURST_LENGTH_SCALE
		* math.clamp(BURST_THICKNESS * percent, BURST_THICKNESS_MIN, BURST_THICKNESS_MAX)

	local targets: { [CharacterEntity]: boolean } = {}
	rootsInBox(
		rotation + (origin + direction * (distance / 2)),
		Vector3.new(beamWidth, distance * BEAM_LENGTH_SCALE, beamWidth),
		entity,
		targets
	)
	rootsInBox(
		rotation + (hitPosition + direction * BURST_FORWARD),
		Vector3.new(burstWidth, burstLength, burstWidth),
		entity,
		targets
	)

	self:PlayEffect(EFFECT, origin, {
		Target = hitPosition,
		Percent = percent,
		Affinity = affinity,
		Haki = haki,
	})

	local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Melee"
	local damage = (if haki then HAKI_DAMAGE else DAMAGE) * power
	local casterPosition = entity.Root.Position
	for target in targets do
		self:Damage(target, damage, trait, nil, false)

		local away = target.Root.Position - casterPosition
		if away.Magnitude > 1e-3 and not target.Dead then
			local force = KNOCKBACK_FORCE * target.Root.AssemblyMass
			self:Impulse(
				target,
				away.Unit * KNOCKBACK * power,
				KNOCKBACK_SECONDS,
				Vector3.new(force, force, force),
				KNOCKBACK_POWER
			)
			if target.Player then
				target:SetStatus(HIT_STATUS, true, KNOCKBACK_SECONDS, true)
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
end

function PhoenixBurst:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return PhoenixBurst
