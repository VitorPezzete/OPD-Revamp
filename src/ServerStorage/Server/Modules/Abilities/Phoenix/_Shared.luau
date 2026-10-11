--!strict
--[[
	Phoenix fruit - everything that is on while the fruit is owned: the fast regeneration
	and the egg. Passives.Phoenix starts / stops it, DamageModifiers.PhoenixEgg feeds it
	every hit. Not an ability (the leading underscore keeps it out of the ability lookup).

	Regeneration
		Legacy, per second, as a fraction of max health:
			base + 0.01 * defense affinity * (1 + BuffRegen * 1.2 / 40)
		(the line before it in HealthV2, "base * (1 + perk...) + 0.02", was always
		overwritten). CharacterService computes (base + BuffRegen * perPoint) * RegenMultiplier,
		so the multiplier is the ratio of the two and is refreshed when a perk changes.
		No regeneration inside the egg (multiplier 0), as in the legacy loop.

	Egg
		A hit that would bring the owner to 0 health is capped so 1 health is left, and the
		owner becomes an egg for 8 s: rooted (jumping still works, as in the legacy game),
		fruit sealed, health refilled over the 8 s on the curve of the legacy tween (its
		default Quad Out easing: 61% of the way after the first 3 s).
		For the first 3 s hits are simply ignored. After that every hit is ignored too but
		removes one of floor(clamp(10 * defense affinity * defense level / cap, 2, 20))
		"hits to crack", and the health the egg refills to (and hatches with) drops to
			max health * (0.5 + 0.5 * (hits left - 1) / (hits at start - 1)).
		Out of hits: the egg cracks and the owner dies. Otherwise it hatches after 8 s with
		the "PhoenixRevived" status for 5 s.

	Differences from the legacy egg (ServerPhoenixEgg / HealthV2 / Damage):
	- Legacy let health reach 0 and tweened it back from 0; the framework kills at 0, so
	  the lethal hit leaves 1 health instead.
	- Legacy only looked at the hit counter when the 8 s ended: a cracked egg sat there
	  until then and died with no killer. Here the hit that takes the last "hit to crack"
	  kills on the spot, through the damage pipeline, so the kill is credited to it.
	  (Legacy also paid the kill rewards on the first lethal hit, even if the phoenix
	  hatched afterwards; now only a real death counts.)
	- Only damage going through CombatService can start the egg. Anything that kills
	  directly (void, reset, a system calling Kill) is a real death; in the legacy game
	  any way of reaching 0 health started it.
	- A hit negated earlier in the pipeline (logia immunity of a second fruit, a dodge)
	  does not chip the egg; legacy counted every call of the damage function.
	- The legacy egg stunned its owner (StunEvent); here it roots and seals instead, so
	  stun-only side effects (camera, stun status icon) do not apply.
	- Legacy had no cooldown at all between two eggs. EGG_COOLDOWN keeps that (0) but the
	  gate exists.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

-- Replicated while the fruit is owned (value: fruit colors). Drives the regen flames.
local PASSIVE_STATUS = "PhoenixPassive"
-- Read by CharacterService's regen loop.
local REGEN_STATUS = "RegenMultiplierPhoenix"
-- Replicated while in the egg (value: fruit colors).
local EGG_STATUS = "PhoenixEgg"
-- Replicated once the egg can be cracked (value: hits left).
local HITS_STATUS = "PhoenixEggHits"
-- Replicated for a few seconds after hatching (value: fruit colors).
local REVIVED_STATUS = "PhoenixRevived"
-- Name of the root and of the seal source.
local EGG_SOURCE = "PhoenixEgg"
local CANCEL_REASON = "PhoenixEgg"

local REGEN_PER_AFFINITY = 0.01
local REGEN_PER_PERK_POINT = 1.2 / 40

local EGG_SECONDS = 8
local ARM_SECONDS = 3
local REVIVED_SECONDS = 5
-- Seconds after hatching during which a lethal hit kills for real. Legacy: none.
local EGG_COOLDOWN = 0
local HITS_BASE = 10
local HITS_MIN = 2
local HITS_MAX = 20
local MIN_HATCH_FRACTION = 0.5
-- Health refill step; the chain is bounded by EGG_SECONDS.
local TICK = 0.1

type Egg = {
	EndsAt: number,
	ArmedAt: number,
	MaxHits: number,
	Hits: number,
}

type Owner = {
	Entity: CharacterEntity,
	Data: any,
	FruitSlot: number,
	Egg: Egg?,
	ReadyAt: number,
}

local owners: { [CharacterEntity]: Owner } = {}

local PhoenixShared = {}

local function getColors(owner: Owner): string
	local fruits = owner.Data.Data.DevilFruits
	return if owner.FruitSlot == 1 then fruits.Slot1.Color else fruits.Slot2.Color
end

local function getDefenseAffinity(owner: Owner): number
	local affinities = owner.Data.Data.Affinities
	local slot = if owner.FruitSlot == 1 then affinities.DF1 else affinities.DF2
	return slot.Defense
end

local function applyRegen(owner: Owner)
	if owner.Egg then
		owner.Entity:SetStatus(REGEN_STATUS, 0)
		return
	end

	local perk: number = owner.Data.Data.Expertise.Perks.BuffRegen.Value
	local normal = StatConfig.BaseRegen + perk * StatConfig.RegenPerPerkPoint
	local phoenix = StatConfig.BaseRegen
		+ REGEN_PER_AFFINITY * getDefenseAffinity(owner) * (1 + perk * REGEN_PER_PERK_POINT)
	owner.Entity:SetStatus(REGEN_STATUS, phoenix / normal)
end

-- Health the egg is refilling to: full while untouched, half with one hit left.
local function getTargetHealth(owner: Owner, egg: Egg): number
	local left = math.max(egg.Hits, 1)
	local fraction = MIN_HATCH_FRACTION + (1 - MIN_HATCH_FRACTION) * (left - 1) / (egg.MaxHits - 1)
	return owner.Entity.MaxHealth * fraction
end

-- Moves health towards the target: `alpha` of the way up, or straight down to it.
local function moveHealth(entity: CharacterEntity, target: number, alpha: number)
	local health = entity.Health
	if health > target then
		entity:TakeDamage(health - target)
	elseif health < target then
		entity:Heal((target - health) * alpha)
	end
end

-- Undoes the egg state without hatching (also the death / fruit lost path).
local function endEgg(owner: Owner)
	local entity = owner.Entity
	owner.Egg = nil
	entity:ClearStatus(EGG_STATUS)
	entity:ClearStatus(HITS_STATUS)
	entity:SetRooted(EGG_SOURCE, false)
	Knit.GetService("AbilityService"):SetSealed(entity, false, nil, EGG_SOURCE)
	if owners[entity] == owner then
		applyRegen(owner)
	end
end

local function hatch(owner: Owner, egg: Egg)
	local entity = owner.Entity
	local target = getTargetHealth(owner, egg)
	endEgg(owner)
	moveHealth(entity, target, 1)
	entity:SetStatus(REVIVED_STATUS, getColors(owner), REVIVED_SECONDS, true)
	owner.ReadyAt = os.clock() + EGG_COOLDOWN
end

local function arm(owner: Owner, egg: Egg)
	if owner.Egg == egg and not owner.Entity.Dead then
		owner.Entity:SetStatus(HITS_STATUS, egg.Hits, nil, true)
	end
end

local function step(owner: Owner, egg: Egg)
	local entity = owner.Entity
	-- A dead owner is cleaned up by the passive's cleanup.
	if owner.Egg ~= egg or entity.Dead then
		return
	end

	local remaining = egg.EndsAt - os.clock()
	if remaining <= 0 then
		hatch(owner, egg)
		return
	end

	-- Quad Out over what is left: the gap to the target shrinks with the square of it.
	local left = math.max(0, 1 - TICK / remaining)
	moveHealth(entity, getTargetHealth(owner, egg), 1 - left * left)
	task.delay(math.min(TICK, remaining), step, owner, egg)
end

local function beginEgg(owner: Owner)
	local entity = owner.Entity
	local levelScale = owner.Data.Data.Skills.Defense.Level / StatConfig.Caps.Defense
	local maxHits = math.floor(math.clamp(HITS_BASE * getDefenseAffinity(owner) * levelScale, HITS_MIN, HITS_MAX))

	local now = os.clock()
	local egg: Egg = {
		EndsAt = now + EGG_SECONDS,
		ArmedAt = now + ARM_SECONDS,
		MaxHits = maxHits,
		Hits = maxHits,
	}
	-- State first: sealing interrupts the abilities, which must already see the egg.
	owner.Egg = egg
	entity:SetStatus(EGG_STATUS, getColors(owner), nil, true)
	entity:SetRooted(EGG_SOURCE, true)
	applyRegen(owner)
	Knit.GetService("AbilityService"):SetSealed(entity, true, nil, EGG_SOURCE)

	task.delay(ARM_SECONDS, arm, owner, egg)
	task.delay(TICK, step, owner, egg)
end

-- DamageModifiers.PhoenixEgg: runs after every other modifier, on the final amounts.
function PhoenixShared.OnDamage(context: CombatTypes.DamageContext)
	local entity = context.Target
	local owner = owners[entity]
	if not owner then
		return
	end

	local egg = owner.Egg
	if egg then
		if os.clock() >= egg.ArmedAt then
			egg.Hits -= 1
			if egg.Hits <= 0 then
				-- Cracked: this hit kills, whatever it was worth.
				context.Amount = 0
				context.TrueAmount = entity.Health
				return
			end
			entity:SetStatus(HITS_STATUS, egg.Hits, nil, true)
		end
		context.Cancelled = true
		context.CancelReason = CANCEL_REASON
		return
	end

	local total = math.max(0, context.Amount) + context.TrueAmount
	if total < entity.Health or os.clock() < owner.ReadyAt then
		return
	end

	context.Amount = math.max(0, entity.Health - 1)
	context.TrueAmount = 0
	beginEgg(owner)
end

function PhoenixShared.IsInEgg(entity: CharacterEntity): boolean
	local owner = owners[entity]
	return owner ~= nil and owner.Egg ~= nil
end

-- Passives.Phoenix: returns the cleanup.
function PhoenixShared.Start(entity: CharacterEntity, data: any, fruitSlot: number): () -> ()
	local owner: Owner = {
		Entity = entity,
		Data = data,
		FruitSlot = fruitSlot,
		Egg = nil,
		ReadyAt = 0,
	}
	owners[entity] = owner

	entity:SetStatus(PASSIVE_STATUS, getColors(owner), nil, true)
	applyRegen(owner)
	local disconnect = data:Observe("Expertise.Perks", function()
		if owners[entity] == owner then
			applyRegen(owner)
		end
	end)

	return function()
		disconnect()
		if owners[entity] == owner then
			owners[entity] = nil
		end
		if owner.Egg then
			endEgg(owner)
		end
		entity:ClearStatus(PASSIVE_STATUS)
		entity:ClearStatus(REGEN_STATUS)
		entity:ClearStatus(REVIVED_STATUS)
	end
end

return PhoenixShared
