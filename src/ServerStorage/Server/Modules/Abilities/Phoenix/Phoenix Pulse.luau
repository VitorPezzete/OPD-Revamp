--!strict
--[[
	Phoenix fruit - Phoenix Pulse: a pulse of healing flames around the phoenix.

	With p = defense affinity * (defense level / cap), on use:
	- the caster heals 0.08 * p of max health; below half health that becomes
	  0.08 * p + 0.2 * (1 - health ratio). Given in 32 parts, one every 0.15625 s (5 s);
	- every other character within 10 * p studs (players and NPCs, friend or foe, exactly
	  as the legacy radius query) heals 5 * 0.08 * p of their own max health, in 32 parts,
	  one every 0.25 s (8 s).
	A character already under a pulse is skipped (the legacy flag could not restart).
	Cooldown: 24 s.

	The heals are a gift already made, like a damage over time: they keep running if the
	caster is stunned, sealed or dies (legacy ran them in a script inside each target), so
	OnInterrupt has nothing to take back. Each chain is bounded (32 steps) and stops when
	its target dies.

	Everyone being healed has the replicated "PhoenixPulse" status for the duration
	(Effects.Status.PhoenixPulse); the burst around the caster is a one-shot.

	Using it lands Fly / Soar and locks them for 3 s (legacy flight disabler): done by
	AbilityService, see Modules.FlightLock.

	Legacy problems fixed here: the area was GetPartBoundsInRadius over every part of the
	map, and the heal ran in a control Script cloned into every character and enemy.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "PhoenixPulse"
local EFFECT = "PhoenixPulse"

local COOLDOWN = 24
local HEAL_FRACTION = 0.08
local RADIUS = 10
local LOW_HEALTH_RATIO = 0.5
local LOW_HEALTH_BONUS = 0.2
local OTHERS_MULTIPLIER = 5
local TICKS = 32
local SELF_INTERVAL = 0.15625
local OTHERS_INTERVAL = 0.25

local PhoenixPulse = Ability.extend()

local function healStep(target: CharacterEntity, amount: number, interval: number, left: number)
	if target.Dead then
		return
	end
	target:Heal(amount)
	if left > 1 then
		task.delay(interval, healStep, target, amount, interval, left - 1)
	end
end

local function startHeal(target: CharacterEntity, total: number, interval: number)
	target:SetStatus(STATUS, true, TICKS * interval, true)
	healStep(target, total / TICKS, interval, TICKS)
end

function PhoenixPulse:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0)
end

function PhoenixPulse:OnBegin()
	local entity = self.Entity
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)

	local power = self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	local fraction = HEAL_FRACTION * power
	local radius = RADIUS * power

	self:PlayEffect(EFFECT, entity.Root.Position, { Radius = radius })

	if not entity:HasStatus(STATUS) then
		local ratio = entity:GetHealthRatio()
		local own = if ratio < LOW_HEALTH_RATIO then fraction + LOW_HEALTH_BONUS * (1 - ratio) else fraction
		startHeal(entity, entity.MaxHealth * own, SELF_INTERVAL)
	end

	-- A heal: allies are who it is for (Hitbox's `friendly`).
	for _, target in Hitbox.Sphere(entity.Root.Position, radius, entity, true) do
		if not target:HasStatus(STATUS) then
			startHeal(target, target.MaxHealth * fraction * OTHERS_MULTIPLIER, OTHERS_INTERVAL)
		end
	end
end

return PhoenixPulse
