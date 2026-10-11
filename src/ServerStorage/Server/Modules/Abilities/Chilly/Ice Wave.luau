--!strict
--[[
	Chilly fruit - Ice Wave (charged): a row of five growing ice spikes bursts out of the
	ground from the caster towards the aim point.

	With c = charge / 100 (charge: 25 per second held, 4 to 100, timed on the server) and
	s = sniper affinity * (sniper level / cap):
	- Spike i (1 to 5) appears 0.2 s after the previous one and stays 3 s. It is a cube
	  of side L(i) = 27 * s * c * i, centered L(i) / 2 further along the aim direction
	  than the previous center (the first one starts from the caster).
	- Everyone a spike touches takes sniper level * affinity * c (Special, not dodgeable;
	  doubled, still Special, with armament haki as in the legacy game) and is frozen:
	  125 * s per second for 3.5 * s * c seconds (see Freeze.luau). A character hit by
	  this user's spikes cannot be hit by them again for 5 s, whichever wave they belong
	  to (the legacy hit list was shared by all the user's waves and released after 5 s).
	- NPCs are frozen by the hit like players. (An older legacy script froze an NPC only
	  5 s after the hit, by which time it was usually dead or the wave interrupted; its
	  later revision froze everyone at once, and that is what is kept.)

	After a release the next wave cannot be started for 3 s (the legacy client held its
	own key back that long; the cooldown is the server's now). It cannot be started
	while Freezing Punch is charging either, as on the legacy client.

	The spikes are client visuals (Effects.OneShot.ChillyIceWave). The server checks the
	same boxes every 0.2 s while spikes exist: 19 bounded checks per cast.

	Legacy problems fixed here:
	- Damage values sat in NumberValues shared by every wave of the user, so a second
	  cast rewrote the damage of spikes still standing.
	- Spikes were server parts with Touched connections found by scanning a folder.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Freeze = require(script.Parent.Freeze)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "ChillyWaveCharging"
local PUNCH_STATUS = "ChillyPunchCharging"
local EFFECT = "ChillyIceWave"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local HAKI_MULTIPLIER = 2
local FREEZE_DAMAGE = 125
local FREEZE_DURATION = 3.5
local SPIKE_COUNT = 5
local SPIKE_BASE_SIZE = 27
local SPIKE_INTERVAL = 0.2
local SPIKE_LIFETIME = 3
local COOLDOWN = 3
-- Size the ice on the hand reaches after 3 s of charging, per unit of s.
local HAND_MAX_SIZE = 10

-- How long a character hit by the spikes is safe from them.
local REHIT_DELAY = 5
-- Checks a spike takes part in, and the last check of a cast.
local LIFE_TICKS = math.round(SPIKE_LIFETIME / SPIKE_INTERVAL)
local LAST_TICK = SPIKE_COUNT - 1 + LIFE_TICKS - 1

type Wave = {
	Spikes: { { CFrame: CFrame, Size: Vector3 } },
	Damage: number,
	FreezeDamage: number,
	FreezeDuration: number,
}

local IceWave = Ability.extend()

local function sweep(self: any, wave: Wave, tick: number, epoch: number)
	if (self.Epoch or 0) ~= epoch then
		return
	end

	-- Spike i appears on tick i - 1 and is checked LIFE_TICKS times.
	for index = math.max(1, tick - LIFE_TICKS + 2), math.min(SPIKE_COUNT, tick + 1) do
		local spike = wave.Spikes[index]
		for _, target in Hitbox.Box(spike.CFrame, spike.Size, self.Entity) do
			local now = os.clock()
			local hitUntil: { [CharacterEntity]: number } = self.HitUntil
			if now >= (hitUntil[target] or 0) then
				hitUntil[target] = now + REHIT_DELAY
				self:Damage(target, wave.Damage, "Special", EFFECT, false)
				Freeze.Apply(self, target, wave.FreezeDamage, wave.FreezeDuration)
			end
		end
	end

	if tick < LAST_TICK then
		task.delay(SPIKE_INTERVAL, sweep, self, wave, tick + 1, epoch)
	end
end

function IceWave:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0) and not self.Entity:HasStatus(PUNCH_STATUS)
end

function IceWave:OnBegin()
	if self.ChargeStart then
		return
	end

	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	-- The legacy start was `IntValue.Value = time()`: rounded to the nearest second, so a
	-- charge counts up to half a second more or less than the key was held. Reproduced.
	local now = time()
	self.ChargeStart -= now - math.round(now)
	local hand = if self.UseLeft then "Left" else "Right"
	local maxSize = HAND_MAX_SIZE * self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	self.Entity:SetStatus(STATUS, string.format("%s|%.2f|%s", hand, maxSize, self:GetColorString()), nil, true)
end

function IceWave:OnEnd(input: Ability.AbilityInput)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity
	self.UseLeft = not self.UseLeft
	entity:ClearStatus(STATUS)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local affinity = self:GetAffinity("Sniper")
	local scale = affinity * self:GetLevelScale("Sniper")
	local chargeScale = charge / 100
	local haki = self.Services.Haki:IsArmamentActive(entity)

	local baseSize = SPIKE_BASE_SIZE * scale * chargeScale
	if baseSize <= 0 then
		return
	end

	local origin = entity.Root.Position
	local direction = input.AimPosition - origin
	if direction.Magnitude < 0.05 then
		direction = entity.Root.CFrame.LookVector
	end
	direction = direction.Unit
	-- lookAt needs an up vector that is not parallel to the direction.
	local up = if math.abs(direction.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis

	if not self.HitUntil then
		self.HitUntil = setmetatable({}, { __mode = "k" })
	end
	local wave: Wave = {
		Spikes = {},
		Damage = self:GetLevel("Sniper") * affinity * chargeScale * (if haki then HAKI_MULTIPLIER else 1),
		FreezeDamage = FREEZE_DAMAGE * scale,
		FreezeDuration = FREEZE_DURATION * scale * chargeScale,
	}

	local center = origin
	for index = 1, SPIKE_COUNT do
		local length = baseSize * index
		center += direction * (length / 2)
		wave.Spikes[index] = {
			CFrame = CFrame.lookAt(center, center + direction, up),
			Size = Vector3.new(length, length, length),
		}
	end

	self:PlayEffect(EFFECT, origin, {
		Direction = direction,
		BaseSize = baseSize,
		Count = SPIKE_COUNT,
		Interval = SPIKE_INTERVAL,
		Lifetime = SPIKE_LIFETIME,
		Haki = haki,
	})

	sweep(self, wave, 0, self.Epoch or 0)
end

function IceWave:OnInterrupt()
	self.ChargeStart = nil
	-- Spikes still standing stop hurting.
	self.Epoch = (self.Epoch or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return IceWave
