--!strict
--[[
	Bomb fruit - helpers shared by its four charged abilities. Not an ability: the loader
	only looks modules up by ability name, so this one is never instantiated.

	Every Bomb ability is "hold to charge, release to detonate". The legacy game let only
	one of them charge at a time (four Charging BoolValues checked by each other); that
	lock is the replicated entity status BombCharging, which also drives the growing
	spheres on the limbs and the charge animation (Effects.Status.BombCharging):

		"<kind>|<max sphere size>|<seconds to reach it>|<fruit colors>|<hand>|<affinity>"
		kind: Punch (one arm), Boost (both legs), Wave (one arm), Full (four limbs)

	Hands. Bomb Punch and Bomb Wave use one hand, then the other, right first, sharing the
	turn (the legacy client kept one "ChargeMode" for both and sent it to the server). The
	turn is kept here, in an unreplicated status, and changes at each release.

	Explosions are a sphere test at the moment of detonation plus one client one-shot
	(Effects.OneShot.BombExplosion). The legacy explosions were server parts tweened by
	the server and tested against every model in Workspace: a character was hit when its
	ROOT was within the radius, with no allowance for its body, which is kept.

	The ball that is drawn is not the hit sphere. The legacy code put the blast length L
	(twice the hit radius of a Punch) in the MESH scale of a small part: 0.5 studs for
	Punch, Boost and Full Body, 0.1 * i studs for blast i of a Wave. Every caller passes
	that pair (Scale, PartSize) and the effect rebuilds the same ball.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local Shared = {}

Shared.ChargeStatus = "BombCharging"
Shared.Effect = "BombExplosion"
Shared.DamageTag = "BombExplosion"

Shared.ChargeMin = 4
Shared.ChargeMax = 100
Shared.HakiMultiplier = 2
-- Size of the legacy explosion part whose mesh was scaled (Punch, Boost, Full Body).
Shared.BallPartSize = 0.5

-- Set while the next Punch / Wave uses the left hand.
local LEFT_HAND_STATUS = "BombLeftHand"

-- Charging sphere on a limb: 12.5 * level scale * affinity studs, reached in 3 s (10 s
-- for Full Body) whatever the charge rate of the ability.
local CHARGE_SPHERE_SIZE = 12.5

function Shared.IsCharging(entity: CharacterEntity): boolean
	return entity:HasStatus(Shared.ChargeStatus)
end

function Shared.GetHand(entity: CharacterEntity): string
	return if entity:HasStatus(LEFT_HAND_STATUS) then "Left" else "Right"
end

function Shared.SwapHand(entity: CharacterEntity)
	entity:SetStatus(LEFT_HAND_STATUS, not entity:HasStatus(LEFT_HAND_STATUS))
end

-- `skill` is the one the limb sphere grows with (not always the ability's own: the
-- legacy Bomb Wave sphere used the melee level and affinity).
function Shared.BeginCharge(ability: any, kind: string, skill: string, growSeconds: number, fullSeconds: number)
	ability:BeginCharge(fullSeconds)
	-- The legacy start of every Bomb charge was `IntValue.Value = time()`, which rounds to
	-- the nearest whole second: a charge counts up to half a second more or less than
	-- the key was really held. Reproduced.
	local now = time()
	ability.ChargeStart -= now - math.round(now)
	-- Ability.Destroy clears ChargeStart before OnInterrupt runs, so ownership of the
	-- shared lock is remembered separately.
	ability.Charging = true
	local affinity: number = ability:GetAffinity(skill)
	local size = CHARGE_SPHERE_SIZE * ability:GetLevelScale(skill) * affinity
	local value = string.format(
		"%s|%.2f|%.2f|%s|%s|%.3f",
		kind,
		size,
		growSeconds,
		ability:GetColorString(),
		Shared.GetHand(ability.Entity),
		affinity
	)
	ability.Entity:SetStatus(Shared.ChargeStatus, value, nil, true)
end

--[[
	Ends the charge of `ability`. Returns nil when it was not the one charging (a release
	that follows an interrupt, or the release of a key whose press was refused).
]]
function Shared.EndCharge(ability: any, rate: number): number?
	local charge = ability:EndCharge(rate, Shared.ChargeMin, Shared.ChargeMax)
	if ability.Charging then
		ability.Charging = false
		ability.Entity:ClearStatus(Shared.ChargeStatus)
	end
	return charge
end

-- Interrupt path of a charging ability: only the one that owns the charge clears the lock.
function Shared.CancelCharge(ability: any)
	if ability.Charging then
		ability.Charging = false
		ability.Entity:ClearStatus(Shared.ChargeStatus)
	end
	ability.ChargeStart = nil
end

--[[
	One explosion: damages everyone within `radius` of `center` (never the caster) and
	plays the blast. `alreadyHit` makes several blasts of one cast hit each target once.
	`blend` picks the blast color between the two fruit colors (0 first, 1 second).
	`extra` is added to the effect message: Scale and PartSize size the ball (see the
	header); { Release = "Punch" | "Wave", Hand, Aim } makes the caster's own client play
	the release clip and turn to the aim point.
]]
function Shared.Explode(
	ability: any,
	center: Vector3,
	radius: number,
	damage: number,
	haki: boolean,
	blend: number,
	template: string,
	alreadyHit: { [CharacterEntity]: boolean }?,
	extra: { [string]: any }?
)
	local params: { [string]: any } = {
		Radius = radius,
		Haki = haki,
		Blend = blend,
		Template = template,
	}
	if extra then
		for key, value in extra do
			params[key] = value
		end
	end
	ability:PlayEffect(Shared.Effect, center, params)

	for _, target in Hitbox.Sphere(center, radius, ability.Entity) do
		-- The legacy test was the root's distance alone.
		if (target.Root.Position - center).Magnitude > radius then
			continue
		end
		if alreadyHit then
			if alreadyHit[target] then
				continue
			end
			alreadyHit[target] = true
		end
		-- Not dodgeable, like the legacy call.
		ability:Damage(target, damage, "Special", Shared.DamageTag, false)
	end
end

-- Position of a limb of the caster, or its root when the limb is missing.
function Shared.LimbPosition(entity: CharacterEntity, limbName: string): Vector3
	local limb = entity.Model:FindFirstChild(limbName)
	return if limb and limb:IsA("BasePart") then limb.Position else entity.Root.Position
end

function Shared.AimDirection(entity: CharacterEntity, aim: Vector3): Vector3
	local direction = aim - entity.Root.Position
	if direction.Magnitude < 0.05 then
		return entity.Root.CFrame.LookVector
	end
	return direction.Unit
end

return Shared
