--!strict
--[[
	Slash fruit - Slash Dismantle (charged): a flying slash.

	Charge: 34 per second held, 4 to 100, timed on the server. With c = charge / 100 and
	f = sword affinity * (sword level / cap):
	- damage (225 + 525 * c) * f * (1 + BuffWeapons / 100), Special, dodgeable, tag
	  "Slash"; armament haki doubles it and makes it Haki;
	- speed (120 + 180 * c) * f studs per second, 2 s of flight;
	- size: the slash model times (1 + 1.5 * c) * f, with a random +-20 %; at charge 95 or
	  more it is 2.5 * f times the model, and if the aim is near a character within
	  150 * f studs (the auto-aim cone of _Shared.Aim) the slash appears 25 studs in
	  front of that character.
	- 0.1 s between two charges.

	Visual: Effects.OneShot.SlashBlade (one of the ten slash meshes, picked here).
	The hitbox is the bounding box of the mesh that was picked, read from the asset
	(_Shared.DismantleSize): an upright slash does not hit like a flat one. MODEL_SIZE
	is only used in a place without the asset.

	Legacy problems fixed here:
	- The remote handler ran the whole attack for any message that was not "StartCharging";
	  without a charge the damage was `nil / 100` and the handler errored.
	- The lock-on target was a part chosen by the client (any part of the map counted).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local SlashShared = require(script.Parent._Shared)

local EFFECT = "SlashBlade"

local CHARGE_RATE = 34
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local FULL_CHARGE = 95
local MIN_DAMAGE = 225
local MAX_DAMAGE = 750
local MIN_SPEED = 120
local MAX_SPEED = 300
local LIFETIME = 2
local LOCK_RANGE = 150
local FULL_SCALE = 2.5
local CHARGE_SCALE = 1.5
local SIZE_JITTER = 20
local MODEL_COUNT = 10
-- Width, height, depth of a slash at scale 1 when the meshes cannot be read.
local MODEL_SIZE = Vector3.new(30, 30, 17)

local SlashDismantle = Ability.extend()

SlashDismantle.Debounce = 0.1

function SlashDismantle:OnBegin()
	if not self.ChargeStart then
		self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	end
end

function SlashDismantle:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local ratio = charge / 100
	local factor = SlashShared.Factor(self)
	local multiplier, trait, haki = SlashShared.Haki(self)
	local full = charge >= FULL_CHARGE

	local origin, direction = SlashShared.Aim(self, input.AimPosition, full, LOCK_RANGE * factor, charge)
	local variant = math.random(1, MODEL_COUNT)
	local speed = (MIN_SPEED + (MAX_SPEED - MIN_SPEED) * ratio) * factor
	local scale = if full
		then FULL_SCALE * factor
		else (1 + CHARGE_SCALE * ratio) * factor * (1 - math.random(-SIZE_JITTER, SIZE_JITTER) / 100)

	SlashShared.Fly(self, {
		Origin = origin,
		Direction = direction,
		Speed = speed,
		Lifetime = LIFETIME,
		Size = SlashShared.DismantleSize(variant, MODEL_SIZE) * scale,
		Damage = (MIN_DAMAGE + (MAX_DAMAGE - MIN_DAMAGE) * ratio) * factor * SlashShared.WeaponBuff(self) * multiplier,
		Trait = trait,
		Dodgeable = true,
	})

	self:PlayEffect(EFFECT, origin, {
		Kind = "Dismantle",
		Variant = variant,
		Direction = direction,
		Speed = speed,
		Lifetime = LIFETIME,
		Scale = scale,
		Haki = haki,
	})
end

function SlashDismantle:OnInterrupt()
	self.ChargeStart = nil
	-- Slashes still in flight vanish.
	self.Epoch = (self.Epoch or 0) + 1
end

return SlashDismantle
