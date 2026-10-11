--!strict
--[[
	Bisento - special: a quake bubble thrown from the blade. Cooldown 23 s.

	0.4 s after the press a bubble leaves the blade towards the aim at 125 studs/s and
	bursts on the first thing it touches (or at the aim point). With L = sword level and
	e = max(1, BuffWeapons perk points) / 100:
	- burst: a cube of side max(10, 4 * b), b = max(1, 35.1 * 0.005 * L * e);
	- damage: 7100 * max(1, L) / 500 * e, Special; doubled and Haki with armament haki.
	  It cannot be dodged and counts as an ability hit (legacy passed "Ability");
	- everyone caught is stunned 1.5 s and slammed down (80 studs/s).

	The perk dependence is legacy and strong: with no BuffWeapons points e is 0.01, so
	the burst is a 10-stud cube dealing 71 at level 500; with 50 points it is a 175-stud
	cube dealing 3550.

	Visuals: Effects.OneShot.WeaponBisento (bubble) and WeaponBisentoBurst.

	Legacy problems fixed: the bubble was a server Part moved every Heartbeat for up to
	15 s; a bubble that touched nothing teleported its burst to the aim point after
	those 15 s (it now simply bursts when it reaches it).
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)
local WeaponShared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity
type WeaponContext = WeaponTypes.WeaponContext

local WINDUP = 0.4
local SPEED = 125
local BUBBLE_SCALE = 35.1 * 0.005
local MIN_SIDE = 10
local SIDE_PER_SCALE = 4
local DAMAGE = 7100
local DAMAGE_LEVEL = 500
local STUN = 1.5
local SLAM = Vector3.new(0, -80, 0)
local STUN_NAME = "WeaponBisento"
local BUBBLE_EFFECT = "WeaponBisento"
local BURST_EFFECT = "WeaponBisentoBurst"

local Bisento: WeaponTypes.WeaponBehaviour = {}

local function burst(context: WeaponContext, position: Vector3, side: number, damage: number, haki: boolean)
	local entity = context.Entity
	local services = context.Services
	services.Effect:Play(BURST_EFFECT, position, { Side = side, Haki = haki })

	for _, target in Hitbox.Box(CFrame.new(position), Vector3.new(side, side, side), entity) do
		services.Status:ApplyStun(target, STUN, STUN_NAME)
		services.Combat:Damage({
			Target = target,
			Attacker = entity,
			Amount = damage,
			Trait = if haki then "Haki" else "Special",
			Style = "Ability",
			Dodgeable = false,
		})
		services.Character:ApplyImpulse(target, SLAM)
	end
end

function Bisento.Special(context: WeaponContext): boolean?
	local entity = context.Entity
	local level = context.Level
	local haki = context.Haki
	local expertise = math.max(1, context.Data.Data.Expertise.Perks.BuffWeapons.Value) / 100

	local side = math.max(MIN_SIDE, SIDE_PER_SCALE * math.max(1, BUBBLE_SCALE * level * expertise))
	local damage = DAMAGE * (math.max(1, level) / DAMAGE_LEVEL) * expertise
	if haki then
		damage *= context.HakiMultiplier
	end
	local aim = context.Aim

	task.delay(WINDUP, function()
		if not context:IsHolding() then
			return
		end

		local origin = WeaponShared.LimbPosition(entity, "Right Arm")
		local offset = aim - origin
		if offset.Magnitude < 1 then
			burst(context, aim, side, damage, haki)
			return
		end
		offset = Projectile.Lead(entity, origin, offset, SPEED, offset.Magnitude)

		context.Services.Effect:Play(BUBBLE_EFFECT, origin, {
			Direction = offset.Unit,
			Speed = SPEED,
			Distance = offset.Magnitude,
			Haki = haki,
		})
		Projectile.Fire({
			Origin = origin,
			Direction = offset,
			Speed = SPEED,
			MaxDistance = offset.Magnitude,
			Owner = entity,
			-- The burst (OnEnd) does the damage, whatever stopped the bubble.
			OnHit = function(_target: CharacterEntity) end,
			OnEnd = function(position: Vector3)
				if not entity.Dead then
					burst(context, position, side, damage, haki)
				end
			end,
		})
	end)
	return true
end

return Bisento
