--!strict
--[[
	Slash fruit - Slash Cleave (charged): a heavy flying slash that leaves its victims
	bleeding.

	Charge: 20 per second held, 4 to 100, timed on the server. With c = charge / 100,
	a = sword affinity and f = a * (sword level / cap):
	- damage (600 + 400 * c) * f * (1 + BuffWeapons / 100), Special, NOT dodgeable, tag
	  "Slash"; armament haki doubles it and makes it Haki;
	- speed (82.5 + 82.5 * c) * f studs per second, 2 s of flight;
	- size: the Cleave model times (1 + 1.5 * c); at charge 95 or more it is 2.5 * f times
	  the model, and if the aim is near a character within 200 * f studs (the auto-aim
	  cone of _Shared.Aim) the slash appears 25 studs in front of that character;
	- bleed on every victim: floor(10 * a) hits of "Bleed" damage, each rolled on its own
	  between floor(90 * f) and floor(175 * f), not dodgeable, without the "Slash" tag.
	  The first lands with the slash, each next one 0.2 to 1.1 s after the previous.
	  Two Cleaves on the same victim bleed side by side. A bleed stops when its victim
	  dies and is not stopped by anything that happens to the caster short of death;
	- 5 s after a release before the next charge can start.

	The bleed is one bounded chain of delays per victim (at most 20 hits), not a status:
	StatusService deals a fixed amount at a fixed interval and restarts on re-application.
	The 5 s cooldown lived on the client only; it is enforced here.

	The server hitbox is MODEL_SIZE, the measured size of the Cleave mesh; the client
	scales the real mesh.

	Legacy quirk kept: below charge 95 the size does not scale with f (Dismantle's does).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local SlashShared = require(script.Parent._Shared)

local EFFECT = "SlashBlade"

local CHARGE_RATE = 20
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local FULL_CHARGE = 95
local MIN_DAMAGE = 600
local MAX_DAMAGE = 1000
local MIN_SPEED = 82.5
local MAX_SPEED = 165
local LIFETIME = 2
local LOCK_RANGE = 200
local FULL_SCALE = 2.5
local CHARGE_SCALE = 1.5
local COOLDOWN = 5
local BLEED_HITS = 10
local BLEED_MIN = 90
local BLEED_MAX = 175
-- Legacy: task.wait(0.2 + math.random() * (1 - 0.1)) between two hits.
local BLEED_MIN_WAIT = 0.2
local BLEED_WAIT_SPREAD = 0.9
-- Width, height, depth of the Cleave mesh at scale 1.
-- Measured: the Cleave mesh is 16 x 31.4 x 38.5 studs (thin axis along the travel direction).
local MODEL_SIZE = Vector3.new(38.5, 31.4, 16)

local SlashCleave = Ability.extend()

local function bleed(self: any, target: CharacterEntity.CharacterEntity, hitsLeft: number, minimum: number, maximum: number)
	if hitsLeft <= 0 or target.Dead or target.Model.Parent == nil or self.Entity.Dead then
		return
	end
	self:Damage(target, math.random(minimum, maximum), "Bleed", nil, false)
	task.delay(BLEED_MIN_WAIT + math.random() * BLEED_WAIT_SPREAD, bleed, self, target, hitsLeft - 1, minimum, maximum)
end

function SlashCleave:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function SlashCleave:OnBegin()
	if not self.ChargeStart then
		self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	end
end

function SlashCleave:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local ratio = charge / 100
	local factor, affinity = SlashShared.Factor(self)
	local multiplier, trait, haki = SlashShared.Haki(self)
	local full = charge >= FULL_CHARGE

	local origin, direction = SlashShared.Aim(self, input.AimPosition, full, LOCK_RANGE * factor, charge)
	local speed = (MIN_SPEED + (MAX_SPEED - MIN_SPEED) * ratio) * factor
	local scale = if full then FULL_SCALE * factor else 1 + CHARGE_SCALE * ratio

	local bleedHits = math.floor(BLEED_HITS * affinity)
	local bleedMin = math.floor(BLEED_MIN * factor)
	local bleedMax = math.max(bleedMin, math.floor(BLEED_MAX * factor))

	SlashShared.Fly(self, {
		Origin = origin,
		Direction = direction,
		Speed = speed,
		Lifetime = LIFETIME,
		Size = MODEL_SIZE * scale,
		Damage = (MIN_DAMAGE + (MAX_DAMAGE - MIN_DAMAGE) * ratio) * factor * SlashShared.WeaponBuff(self) * multiplier,
		Trait = trait,
		Dodgeable = false,
		OnHit = function(target: CharacterEntity.CharacterEntity)
			bleed(self, target, bleedHits, bleedMin, bleedMax)
		end,
	})

	self:PlayEffect(EFFECT, origin, {
		Kind = "Cleave",
		Variant = 1,
		Direction = direction,
		Speed = speed,
		Lifetime = LIFETIME,
		Scale = scale,
		Haki = haki,
	})
end

function SlashCleave:OnInterrupt()
	self.ChargeStart = nil
	-- A slash still in flight vanishes; bleeds already applied run out on their own.
	self.Epoch = (self.Epoch or 0) + 1
end

return SlashCleave
