--!strict
--[[
	Dough fruit - Dough Bazooka (charged): two mochi rings open above the user's shoulders
	and each fires an arm at the aim point.

	With f0 = Shared.Factor (melee), t = seconds held clamped to 0.5 - 5 and
	f = f0 / 5 * t:
	- aim point: where the mouse is at the release, at most 500 studs from the user (the
	  source client brought it back to 500);
	- 1.125 * f seconds after the release (the rings take 1 * f s to open and the arms
	  0.125 * f s to arrive) everyone within 20 * f studs of the aim point is hit:
	  10000 * f Haki damage with armament haki (read at the release), otherwise
	  5000 * f Melee; not dodgeable;
	- and is pushed for 0.25 s at 1000 * f studs per second along the line from a point
	  10 studs above and 5 studs (world +Z, as written in the source) beside the user to
	  the aim point (BodyVelocity, MaxForce inf, P 10000). The push is applied whether or
	  not the damage was negated, as in the source.
	- cooldown: 1 s from the release (`clamp(1 * f, 1, 1)`).

	One sphere, one hit: the two arms are a visual (Effects.OneShot.DoughBazooka).
	The hit that is already on its way lands even if the user is stunned or sealed in the
	meantime (the source's task.delay); only death stops it.

	Flight lock: raised on press and release in the source; see Burning Mochi.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local NAME = "Dough Bazooka"
local SKILL = "Melee"
local EFFECT = "DoughBazooka"
local DAMAGE_TAG = "DoughBazooka"

local COOLDOWN = 1
local MIN_CHARGE = 0.5
local MAX_CHARGE = 5
local MAX_DAMAGE = 10000
local MAX_AIM = 500
local HIT_DELAY = 1.125
local HIT_RADIUS = 20
local KNOCKBACK = 1000
local KNOCKBACK_TIME = 0.25
local KNOCKBACK_FORCE = Vector3.new(math.huge, math.huge, math.huge)
local KNOCKBACK_POWER = 10000
local KNOCKBACK_FROM = Vector3.new(0, 10, 5)
-- The visual reaches up to MAX_AIM away from its origin.
local EFFECT_RADIUS = 900

local DoughBazooka = Ability.extend()
-- The source dealt this damage without a style: ResistAbilities does not apply.
DoughBazooka.DamageStyle = "Plain"

function DoughBazooka:CanBegin(): boolean
	return not self.Charging and os.clock() >= (self.ReadyAt or 0) and not Shared.IsUsing(self.Entity)
end

function DoughBazooka:OnBegin()
	local entity = self.Entity
	self.Charging = true
	Shared.SetUsing(entity, NAME)
	self:BeginCharge(MAX_CHARGE)
	entity:SetStatus(Shared.ChargingStatus, "Bazooka", nil, true)
end

function DoughBazooka:OnEnd(input: Ability.AbilityInput)
	if not self.Charging then
		return
	end
	local entity = self.Entity
	local held = Shared.HeldSeconds(self, MIN_CHARGE, MAX_CHARGE)
	self:Cancel()
	if not held then
		return
	end

	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
	self.Services.Ability:RaiseFlightLock(entity)

	local factor = Shared.Factor(self, SKILL) / MAX_CHARGE * held
	if factor <= 0 then
		return
	end
	local haki = Shared.Haki(self)

	local rootPosition = entity.Root.Position
	local aim = input.AimPosition
	local offset = aim - rootPosition
	if offset.Magnitude > MAX_AIM then
		aim = rootPosition + offset.Unit * MAX_AIM
	end

	self:PlayEffect(EFFECT, rootPosition, { Factor = factor, Aim = aim, Haki = haki }, EFFECT_RADIUS)

	local damage = if haki then MAX_DAMAGE * factor else MAX_DAMAGE / 2 * factor
	local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Melee"

	task.delay(HIT_DELAY * factor, function()
		if entity.Dead then
			return
		end
		local from = entity.Root.Position + KNOCKBACK_FROM
		local push = aim - from
		local velocity = if push.Magnitude > 1e-3 then push.Unit * KNOCKBACK * factor else Vector3.zero

		for _, target in Hitbox.Sphere(aim, HIT_RADIUS * factor, entity) do
			self:Damage(target, damage, trait, DAMAGE_TAG, false)
			if not target.Dead then
				self:Impulse(target, velocity, KNOCKBACK_TIME, KNOCKBACK_FORCE, KNOCKBACK_POWER)
			end
		end
	end)
end

function DoughBazooka:Cancel()
	self.Charging = false
	self.Entity:ClearStatus(Shared.ChargingStatus)
	Shared.ClearUsing(self.Entity, NAME)
end

function DoughBazooka:OnInterrupt()
	if self.Charging then
		self:Cancel()
	end
end

return DoughBazooka
