--!strict
--[[
	Luck fruit - Golden Casino: a casino room with a giant spinning skull opens where
	the caster stands. Needs 75 luck (not spent). 30 s cooldown.

	With d = defense affinity:
	Duration:  5 * d seconds; the room stays where it was cast.
	Radius:    250 * d / 2.
	Damage:    every second (first tick at once), everyone inside takes
	           clamp(their max health / 40 * d, 1000, 3000), "Special", not dodgeable.
	While it runs the caster is "Lucky": dice and coins roll 4-6, the slot machine has
	no skulls, and Fortune's Purge can burst the skull.
	The room does not close when its caster is stunned (it never did), and it can be
	opened while stunned: like the other Luck powers it had no "powers disabled" check
	in the legacy game (the seal gate of AbilityService still applies).

	Two statuses carry it: "LuckCasino" (replicated; Effects.Status.LuckCasino builds
	the room and the skull from its value) and "LuckCasinoArea" (server only; position
	and radius for Fortune's Purge).

	Legacy problems fixed here:
	- The damage loop ran inside the remote handler and the room was rotated by a
	  server Heartbeat connection that the end timer indexed before it was assigned.
	- A second cast replaced the script-level BigSkull while the first room's timer
	  still pointed at it, destroying the new room early.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "LuckCasino"

local LUCK_REQUIRED = 75
local DURATION = 5
local DIAMETER = 250
local TICK = 1
local HEALTH_FRACTION = 1 / 40
local MIN_DAMAGE = 1000
local MAX_DAMAGE = 3000

local GoldenCasino = Ability.extend()
-- The legacy script never checked for disabled powers: a seal does not stop it.
GoldenCasino.IgnoreSeal = true

GoldenCasino.Debounce = 30
GoldenCasino.KeepThroughStun = true

function GoldenCasino:CanBegin(): boolean
	local entity = self.Entity
	return not self.Active and Shared.Get(entity) >= LUCK_REQUIRED
end

function GoldenCasino:OnBegin()
	local entity: CharacterEntity = self.Entity
	local affinity = self:GetAffinity("Defense")
	local position = entity.Root.Position
	local diameter = DIAMETER * affinity
	local radius = diameter / 2
	local duration = DURATION * affinity
	local endsAt = os.clock() + duration

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local area: Shared.CasinoArea = { Position = position, Radius = radius, EndsAt = endsAt }
	entity:SetStatus(Shared.CasinoAreaStatus, area)
	entity:SetStatus(Shared.CasinoStatus, Shared.PackCasino(position, diameter, false, self:GetColorString()), duration, true)

	local function step()
		if self.Run ~= run then
			return
		end
		if os.clock() >= endsAt then
			self:OnInterrupt()
			return
		end

		for _, target in Hitbox.Sphere(position, radius, entity) do
			local damage = math.clamp(target.MaxHealth * HEALTH_FRACTION * affinity, MIN_DAMAGE, MAX_DAMAGE)
			self:Damage(target, damage, "Special", EFFECT, false)
		end
		task.delay(TICK, step)
	end
	step()
end

function GoldenCasino:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1

	local entity: CharacterEntity = self.Entity
	entity:ClearStatus(Shared.CasinoStatus)
	entity:ClearStatus(Shared.CasinoAreaStatus)
end

return GoldenCasino
