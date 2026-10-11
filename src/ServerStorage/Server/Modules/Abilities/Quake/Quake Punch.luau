--!strict
--[[
	Quake fruit - Quake Punch (charged): a punch that cracks the air in front of the fist.

	DESIGNED HERE, NOT PORTED. In the legacy game this ability did nothing: the client
	function returned before doing anything (`if DF_Disabled == true then return end`
	followed by `if DF_Disabled == false then return end`) and the server branch only
	stored a debounce. QuakeOld is the same. What the dead code still shows is kept:
	- level requirement and skill (melee 100, in FruitConfig);
	- charge 4 to 100, one point per `wait()` on the server, i.e. about 30 per second;
	- cooldown `charge * 0.3 / melee affinity` seconds, where the client charge was never
	  raised from 4: 1.2 / affinity seconds;
	- the fists alternate, with the punch hold / swing animations of the charging hand.
	Everything below is new and follows the other three Quake abilities. With a = melee
	affinity, s = melee level / cap and c = charge / 100:
	- hit: a box 12 wide, 8 tall and 14 deep in front of the caster;
	- damage: 1600 * a * s * c, Special (the Quake Stomp base), dodgeable; armament haki
	  doubles it and makes it Haki;
	- knockback: 100 * a * s * c studs per second away from the caster, slightly upward.
	Review these numbers before release.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local EFFECT = "QuakeCrack"
local DAMAGE_TAG = "QuakePunch"

local CHARGE_RATE = 30
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local COOLDOWN = 1.2

local HIT_SIZE = Vector3.new(12, 8, 14)
local HIT_DISTANCE = 7
local DAMAGE = 1600
local KNOCKBACK = 100
local KNOCKBACK_LIFT = 0.25
-- Length of the cracks drawn at the fist, per point of charge.
local CRACK_FORCE = 0.06

local QuakePunch = Ability.extend()

function QuakePunch:CanBegin(): boolean
	return Shared.CanCharge(self)
end

function QuakePunch:OnBegin()
	Shared.BeginCharge(self, "Punch", 0, CHARGE_MAX / CHARGE_RATE)
end

function QuakePunch:OnEnd()
	local entity = self.Entity
	-- The real hold: the dead legacy code counted this charge in a loop, not from a clock.
	local _, charge = Shared.EndCharge(self, CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end
	Shared.Swing(self, "Punch")

	local affinity = self:GetAffinity("Melee")
	local power = affinity * self:GetLevelScale("Melee") * charge / CHARGE_MAX
	self.ReadyAt = os.clock() + COOLDOWN / affinity
	self:StartCooldown(COOLDOWN / affinity)

	local haki = self.Services.Haki:IsArmamentActive(entity)
	local damage = DAMAGE * power * (if haki then Shared.HAKI_MULTIPLIER else 1)
	local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Special"

	local root = entity.Root.CFrame
	local look = root.LookVector
	local push = Vector3.new(look.X, KNOCKBACK_LIFT, look.Z).Unit * KNOCKBACK * power

	for _, target in Hitbox.InFront(entity, HIT_SIZE, HIT_DISTANCE) do
		if self:Damage(target, damage, trait, DAMAGE_TAG) > 0 then
			self:Impulse(target, push)
		end
	end

	local side = if self.RightSide then 1.5 else -1.5
	self:PlayEffect(EFFECT, entity.Root.Position, {
		CFrame = root * CFrame.new(side, 0.5, -3),
		Force = math.max(charge * CRACK_FORCE, 1),
		Haki = haki,
		Sound = true,
	})
end

function QuakePunch:OnInterrupt()
	Shared.CancelCharge(self)
end

return QuakePunch
