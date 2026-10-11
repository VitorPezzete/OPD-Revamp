--!strict
--[[
	Ice Dagger - special: 4 to 6 ice blades appear around the user, one every 0.15 s, and
	home on the character under the aim at 95 studs/s for up to 6 s. Each one that
	reaches it (within 5 studs) deals 15 + 0.65 * sword level (x2 and Haki with armament
	haki, then the BuffWeapons perk); they cannot be dodged. Cooldown 5.5 s, not spent
	when there is nobody under the aim.

	The target is chosen by the server: the closest character within 6 studs of the aim
	point. The legacy remote took the target part from the client, so an exploiter could
	point the blades at anyone on the map.

	No blade exists on the server. Each one is a position advanced towards the target a
	few times per second (the legacy version moved a model every Heartbeat); the blades
	seen by players are Effects.OneShot.WeaponIceDagger, flown by each client.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type WeaponContext = WeaponTypes.WeaponContext

local TARGET_RADIUS = 6
local MIN_BLADES = 4
local MAX_BLADES = 6
local BLADE_INTERVAL = 0.15
local SPEED = 95
local TRACK_SECONDS = 6
local HIT_DISTANCE = 5
local BASE_DAMAGE = 15
local LEVEL_DAMAGE = 0.65
local MIN_STEP = 0.05
local MAX_STEP = 0.4
local EFFECT = "WeaponIceDagger"

local IceDagger: WeaponTypes.WeaponBehaviour = {}

local function fly(context: WeaponContext, target: CharacterEntity, position: Vector3, damage: number, expiresAt: number)
	if target.Dead or os.clock() >= expiresAt then
		return
	end

	local offset = target.Root.Position - position
	local distance = offset.Magnitude
	if distance < HIT_DISTANCE then
		context.Services.Combat:Damage({
			Target = target,
			Attacker = context.Entity,
			Amount = damage,
			Trait = if context.Haki then "Haki" else "Sword",
			Style = "Weapon",
			Dodgeable = false,
		})
		return
	end

	local step = math.clamp((distance - HIT_DISTANCE) / SPEED, MIN_STEP, MAX_STEP)
	task.delay(step, function()
		fly(context, target, position + offset.Unit * math.min(SPEED * step, distance), damage, expiresAt)
	end)
end

function IceDagger.Special(context: WeaponContext): boolean?
	local entity = context.Entity
	local target = Hitbox.Closest(Hitbox.Sphere(context.Aim, TARGET_RADIUS, entity), context.Aim)
	if not target then
		return false
	end

	local damage = (BASE_DAMAGE + LEVEL_DAMAGE * context.Level) * context.HakiMultiplier * context.PerkMultiplier
	local count = math.random(MIN_BLADES, MAX_BLADES)

	context.Services.Effect:Play(EFFECT, entity.Root.Position, {
		Caster = entity.Model,
		Target = target.Model,
		Count = count,
		Interval = BLADE_INTERVAL,
		Speed = SPEED,
		Lifetime = TRACK_SECONDS,
		Haki = context.Haki,
	})

	for index = 1, count do
		task.delay((index - 1) * BLADE_INTERVAL, function()
			if entity.Dead or target.Dead then
				return
			end
			local spawn = entity.Root.Position + Vector3.new(math.random(-6, 6), math.random(4, 8), math.random(-6, 6))
			fly(context, target, spawn, damage, os.clock() + TRACK_SECONDS)
		end)
	end
	return true
end

return IceDagger
