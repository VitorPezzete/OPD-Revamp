--!strict
--[[
	Gas fruit - Airless World (toggle): the air is removed from a sphere around the
	caster; whoever is inside loses health faster and faster.

	With a = defense affinity and L = defense level, read when the aura is turned on:
	- Radius 50 * (L / cap) * a studs, centred on the caster and moving with it.
	- A victim is hurt once per second, starting one second after it first enters.
	  The n-th hit deals
	      current health * (2p + n * p) + 10 * n     with p = L * a / 200000
	  "Special" damage, not dodgeable. n starts at 0 for NPCs and at 1 for players (the
	  two legacy control scripts counted differently: level 500, affinity 2 is 1%, 1.5%,
	  2%... of an NPC's current health and 1.5% + 10, 2% + 20... of a player's). n
	  restarts once the effect has fully worn off.
	- After leaving the sphere the effect goes on for 4 * a seconds.
	- Luck fruit owners take none of it (DamageModifiers.GasAirlessImmunity).
	- Using it grounds the gas form for 3s.

	The legacy game kept this in a "GasAirless" control script cloned into every
	character. Here the aura keeps one small table of victims, checked five times a
	second (the legacy sampling rate) while the aura is on, and deals the hits itself:
	StatusService DoTs have a fixed damage and cannot express "percentage of current
	health, growing per tick". The tick is not capped in time (the toggle was not either).
	When the aura ends (toggle, death, seal) the hits still owed to each victim are handed
	to StatusService:ApplyDot as a fixed DoT of the next hit's value, so the lingering
	part needs nothing from this object. Victims carry the replicated "GasAirless" status.

	Legacy problems fixed here:
	- The aura loop was `while script.Airless.Value` with the particle part as the only
	  off switch: dying with it on left the loop (and a GetPartBoundsInRadius over up to
	  100 studs, five times a second) running on the next character.
	- A second press during the 0.2s wait could start a second loop.
	- The sphere, its particles and welds were server instances.
	- Teammates are no longer affected.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity
type Victim = { Count: number, NextDamage: number, LastSeen: number }

-- Caster: "<radius>|<colors>", drives the sphere drawn by Effects.Status.GasAirlessWorld.
local STATUS = "GasAirlessWorld"
-- Victims: replicated flag, also the name of the lingering DoT and the damage tag.
local VICTIM_STATUS = "GasAirless"

local BASE_RADIUS = 50
local LINGER_PER_AFFINITY = 4
local PERCENTAGE_DIVISOR = 200000
local FLAT_PER_COUNT = 10
local DAMAGE_INTERVAL = 1
local TICK = 0.2

local AirlessWorld = Ability.extend()
-- Already running, it outlives a seal as it did in the legacy game.
AirlessWorld.KeepThroughSeal = true

-- The legacy aura was only ever ended by its own key: a stun did not stop it (but the
-- key cannot be used while stunned).
AirlessWorld.KeepThroughStun = true

function AirlessWorld:CanBegin(): boolean
	return not self.Entity:HasStatus("Stunned")
end

-- `count`: hits already taken. The legacy script of player characters counted the hit
-- before computing it, the one of NPCs after.
local function hitDamage(target: CharacterEntity, percentage: number, count: number): number
	local step = if target.Player then count + 1 else count
	return target.Health * (percentage * 2 + step * percentage) + FLAT_PER_COUNT * step
end

local function isGone(target: CharacterEntity): boolean
	return target.Dead or target.Model.Parent == nil
end

function AirlessWorld:OnBegin()
	local entity = self.Entity

	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local affinity = self:GetAffinity("Defense")
	local radius = BASE_RADIUS * self:GetLevelScale("Defense") * affinity
	local linger = LINGER_PER_AFFINITY * affinity
	local percentage = self:GetLevel("Defense") * affinity / PERCENTAGE_DIVISOR

	local victims: { [CharacterEntity]: Victim } = {}
	self.Victims = victims
	self.Linger = linger
	self.Percentage = percentage

	entity:SetStatus(STATUS, `{math.round(radius * 10) / 10}|{self:GetColorString()}`, nil, true)

	local status = self.Services.Status

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end
		local now = os.clock()

		for _, target in Hitbox.Sphere(entity.Root.Position, radius, entity) do
			if entity.Team ~= "" and entity.Team == target.Team then
				continue
			end

			local victim = victims[target]
			if not victim then
				victim = { Count = 0, NextDamage = now + DAMAGE_INTERVAL, LastSeen = now }
				victims[target] = victim
				-- Replaces what a previous aura of this fruit may have left lingering.
				status:Clear(target, VICTIM_STATUS)
				target:SetStatus(VICTIM_STATUS, true, nil, true)
			end
			victim.LastSeen = now
		end

		for target, victim in victims do
			if isGone(target) or now - victim.LastSeen > linger then
				victims[target] = nil
				target:ClearStatus(VICTIM_STATUS)
			elseif now >= victim.NextDamage then
				victim.NextDamage += DAMAGE_INTERVAL
				self:Damage(target, hitDamage(target, percentage, victim.Count), "Special", VICTIM_STATUS, false)
				victim.Count += 1
			end
		end

		task.delay(TICK, tick)
	end
	task.delay(TICK, tick)
end

function AirlessWorld:OnInterrupt()
	self.Active = false
	-- Invalidates the pending tick of the run that just ended.
	self.Run = (self.Run or 0) + 1

	local entity = self.Entity
	entity:ClearStatus(STATUS)

	local victims: { [CharacterEntity]: Victim }? = self.Victims
	if not victims then
		return
	end
	self.Victims = nil

	-- A caster that is gone deals nothing more (the legacy script stopped as well).
	local canLinger = not entity.Dead and entity.Model.Parent ~= nil
	local linger: number, percentage: number = self.Linger, self.Percentage
	local status = self.Services.Status
	local now = os.clock()

	for target, victim in victims do
		target:ClearStatus(VICTIM_STATUS)

		local ticks = math.ceil(linger - (now - victim.LastSeen))
		if canLinger and ticks > 0 and not isGone(target) then
			status:ApplyDot(target, VICTIM_STATUS, {
				Source = entity,
				Damage = hitDamage(target, percentage, victim.Count),
				Interval = DAMAGE_INTERVAL,
				Ticks = ticks,
				Trait = "Special",
			})
		end
	end
end

return AirlessWorld
