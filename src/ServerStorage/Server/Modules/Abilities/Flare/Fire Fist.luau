--!strict
--[[
	Flare fruit - Fire Fist (charged): a fist of fire thrown at the aim point.

	Charge: 25 per second held, 4 to 100 (timed on the server).
	With a = sniper affinity and s = sniper level / cap:
	- damage = clamp(charge * 10 * a * s, 50 * a, 2000 * a), Special;
	  with armament haki at release it is doubled and Haki;
	- burn   = clamp(100 * s * a, 10 * a, 100 * a) every 0.5 s for 20 s ("FlareBurn"),
	  applied to everyone the fist touches, heat-proof or not (as in the legacy game);
	- size   = max(template size * charge / 100, 4) * a * s on each axis.
	The fist flies at 250 studs/s for 6 s (1500 studs), through characters AND through
	the map, and hits each character once - those it already covers when it appears
	included. The charging fire and the animations alternate hands, right first: the
	charge status carries the hand ("<Right|Left>|<colors>"). The fist itself always
	leaves the RIGHT arm, as in the legacy game (its release message never told the
	server which hand had punched).

	Rumble / Smelt / Hot / Magma / Plasma owners take no direct damage, and those plus
	Luck / Flare owners no burn tick (DamageModifiers.FlareBurnImmunity, tags "FlareHeat"
	and "FlareBurn").

	The legacy fist was an unanchored server part pushed by a BodyVelocity (250 studs/s,
	MaxForce 1e5, P 1250, so it kept a straight line) with a Touched script that only
	reacted to characters and never removed the fist: nothing but its 6 s ended it. A
	ball up to 40 studs wide that appears on the caster's arm sits half in the ground, so
	it did not collide with the map; the server projectile ignores the world too. The
	server reads the template size (a 20 stud ball) from the asset in ReplicatedStorage
	to size its cast and falls back to FALLBACK_SIZE.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

local CHARGE_STATUS = "FlareFistCharging"
local EFFECT = "FlareFist"
local DAMAGE_TAG = "FlareHeat"
local BURN = "FlareBurn"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100

local DAMAGE_PER_CHARGE = 10
local DAMAGE_MIN = 50
local DAMAGE_MAX = 2000
local HAKI_MULTIPLIER = 2

local BURN_DAMAGE = 100
local BURN_MIN = 10
local BURN_INTERVAL = 0.5
local BURN_TICKS = 40

local MIN_SIZE = 4
local FALLBACK_SIZE = Vector3.new(20, 20, 20)
local SPEED = 250
local LIFETIME = 6
-- The arm the fist leaves from, whichever hand is punching.
local ORIGIN_ARM = "Right Arm"

local FireFist = Ability.extend()

local function getTemplateSize(): Vector3
	local current: Instance? = ReplicatedStorage:FindFirstChild("Assets")
	for _, name in { "Models", "Fruits", "Flare", "Power2", "Fire Fist" } do
		current = if current then current:FindFirstChild(name) else nil
	end
	return if current and current:IsA("BasePart") then current.Size else FALLBACK_SIZE
end

function FireFist:OnBegin()
	local entity = self.Entity
	-- Press and release ground the flights for 3 s: AbilityService (Modules.FlightLock).

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	local hand = if self.UseLeft then "Left" else "Right"
	entity:SetStatus(CHARGE_STATUS, `{hand}|{self:GetColorString()}`, nil, true)
end

function FireFist:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end
	local left = self.UseLeft == true
	self.UseLeft = not left

	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Sniper")
	local scale = self:GetLevelScale("Sniper")
	local percent = charge / CHARGE_MAX
	local multiplier = affinity * scale

	local damage = math.clamp(charge * DAMAGE_PER_CHARGE * multiplier, DAMAGE_MIN * affinity, DAMAGE_MAX * affinity)
	local trait: CombatTypes.DamageTrait = "Special"
	local haki = self.Services.Haki:IsArmamentActive(entity)
	if haki then
		damage *= HAKI_MULTIPLIER
		trait = "Haki"
	end
	local burn = math.clamp(BURN_DAMAGE * multiplier, BURN_MIN * affinity, BURN_DAMAGE * affinity)

	local template = getTemplateSize()
	local diameter = math.max(template.X, template.Y, template.Z) * percent
	local radius = math.max(diameter, MIN_SIZE) * multiplier / 2

	local arm = entity.Model:FindFirstChild(ORIGIN_ARM)
	local origin = if arm and arm:IsA("BasePart") then arm.Position else entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	local range = SPEED * LIFETIME
	direction = Projectile.Lead(entity, origin, direction.Unit, SPEED, range)
	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		Speed = SPEED,
		Range = range,
		Percent = percent,
		Multiplier = multiplier,
		Haki = haki,
		Hand = if left then "Left" else "Right",
	})

	Projectile.Fire({
		Origin = origin,
		Direction = direction,
		Speed = SPEED,
		MaxDistance = range,
		Radius = radius,
		Owner = entity,
		Pierce = true,
		IgnoreWorld = true,
		HitOverlapping = true,
		OnHit = function(target: CharacterEntity)
			self:Damage(target, damage, trait, DAMAGE_TAG, false)
			self.Services.Status:ApplyDot(target, BURN, {
				Source = entity,
				Damage = burn,
				Interval = BURN_INTERVAL,
				Ticks = BURN_TICKS,
				Trait = "Special",
			})
		end,
	})
end

function FireFist:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return FireFist
