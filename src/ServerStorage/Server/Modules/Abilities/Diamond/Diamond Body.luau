--!strict
--[[
	Diamond fruit - Diamond Body (toggle): the body turns to diamond, paid for with a
	stamina reserve that every hit taken drains.

	With p = (defense level / cap) * affinity ^ affinity   (defense affinity):
	- Max stamina 20000 * p. Starts full.
	- While active every hit drains its damage (after shield and perk resistances,
	  before the diamond reduction) from the reserve, including hits that end up ignored.
	- While inactive the reserve refills 500 * p per second (applied when turned on).
	- Toggling has a 5s cooldown. When the reserve runs out the body shatters and cannot
	  be used again for 20 * (3 - affinity) seconds.
	- A stun does not break the body (KeepThroughStun), as in the legacy game, where
	  nothing turned it off but the key and an empty reserve; while stunned it can be
	  turned off but not on, as there. Death, a seal and losing the fruit still end it.

	The damage side (ignore small hits, reduce the rest) is DamageModifiers/DiamondBody,
	gated on the DiamondBodyGuard status set here. That status carries the reduction,
	the small-hit threshold and a Drain callback, so stamina never leaves this file.

	The reserve itself is kept in a server-only status on the entity instead of on the
	ability object: AbilityService throws ability objects away on every interrupt
	(stun, seal), which would otherwise refill the reserve and erase the shatter
	cooldown. It still resets on respawn, as it did when it was a value in the character.

	Legacy problems fixed here:
	- Stamina lived in an IntValue under a RemoteEvent, watched by a 10 Hz loop per
	  active body (which also recolored the shell); depletion is now detected on the
	  hit that causes it.
	- The toggle cooldown was a script-level variable raised to the shatter cooldown
	  and only lowered again by the next successful activation.
	- The shell parts were server instances that stayed on the corpse.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

-- Replicated: value is the fruit color string the client paints the shell with.
local STATUS = "DiamondBody"
-- Replicated while active: remaining stamina as a 0-1 fraction, for a HUD bar.
local STAMINA_STATUS = "DiamondBodyStamina"
-- Server only: { Reduction, Threshold, Drain } read by the damage modifier.
local GUARD_STATUS = "DiamondBodyGuard"
-- Server only, permanent: the stamina reserve of this character.
local RESERVE_STATUS = "DiamondBodyReserve"

local MAX_STAMINA = 20000
local REGEN_PER_SECOND = 500
local REDUCTION = 0.35
local TOGGLE_COOLDOWN = 5
local SHATTER_COOLDOWN = 20
local SHATTER_AFFINITY_CEILING = 3
-- Set by StatusService while any stun is running.
local STUN_STATUS = "Stunned"

type Reserve = {
	Stamina: number,
	Max: number,
	-- os.clock() when the body was last turned off (start of the refill).
	OffSince: number,
	NextToggle: number,
}

local DiamondBody = Ability.extend()

DiamondBody.KeepThroughStun = true

local function getPower(self: any): number
	local affinity = self:GetAffinity("Defense")
	return self:GetLevelScale("Defense") * affinity ^ affinity
end

local function getReserve(self: any): Reserve
	local reserve: Reserve? = self.Entity:GetStatus(RESERVE_STATUS)
	if not reserve then
		local max = math.max(1, MAX_STAMINA * getPower(self))
		reserve = { Stamina = max, Max = max, OffSince = os.clock(), NextToggle = 0 }
		self.Entity:SetStatus(RESERVE_STATUS, reserve)
	end
	return reserve :: Reserve
end

local function replicateStamina(self: any, reserve: Reserve)
	local fraction = math.clamp(reserve.Stamina / reserve.Max, 0, 1)
	self.Entity:SetStatus(STAMINA_STATUS, math.floor(fraction * 100 + 0.5) / 100, nil, true)
end

function DiamondBody:CanBegin(): boolean
	-- KeepThroughStun lets presses through during a stun: the body can then be dropped,
	-- not raised.
	return (self.Active or not self.Entity:HasStatus(STUN_STATUS)) and os.clock() >= getReserve(self).NextToggle
end

function DiamondBody:OnBegin()
	local reserve = getReserve(self)
	local now = os.clock()
	reserve.NextToggle = now + TOGGLE_COOLDOWN
	self:StartCooldown(TOGGLE_COOLDOWN)

	if self.Active then
		self:OnInterrupt()
		return
	end
	self.Active = true

	local power = getPower(self)
	reserve.Max = math.max(1, MAX_STAMINA * power)
	reserve.Stamina = math.clamp(reserve.Stamina + (now - reserve.OffSince) * REGEN_PER_SECOND * power, 1, reserve.Max)

	local affinity = self:GetAffinity("Defense")
	self.Entity:SetStatus(GUARD_STATUS, {
		Reduction = REDUCTION * self:GetLevelScale("Defense") * affinity,
		-- Hits weaker than the defense level bounce off.
		Threshold = self:GetLevel("Defense"),
		Drain = function(amount: number)
			if not self.Active then
				return
			end

			reserve.Stamina -= amount
			if reserve.Stamina <= 0 then
				reserve.Stamina = 0
				self:OnInterrupt()
				-- After OnInterrupt so nothing in it can shorten the shatter cooldown.
				local shatterCooldown = SHATTER_COOLDOWN * (SHATTER_AFFINITY_CEILING - affinity)
				reserve.NextToggle = os.clock() + shatterCooldown
				self:StartCooldown(shatterCooldown)
			else
				replicateStamina(self, reserve)
			end
		end,
	})
	self.Entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	replicateStamina(self, reserve)
end

function DiamondBody:OnInterrupt()
	if self.Active then
		getReserve(self).OffSince = os.clock()
	end
	self.Active = false
	self.Entity:ClearStatus(GUARD_STATUS)
	self.Entity:ClearStatus(STAMINA_STATUS)
	self.Entity:ClearStatus(STATUS)
end

return DiamondBody
