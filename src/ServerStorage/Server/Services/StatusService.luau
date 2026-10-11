--!strict
--[[
	Timed effects applied to characters: damage over time, stuns and slows.

	The legacy game cloned a BoolValue plus a control Script per effect into every
	character and enemy (burn, poison, candy, snow, ...), each running its own loop.
	Here every effect is a row in one table, advanced by a single loop.

	Re-applying an effect with the same name refreshes it instead of stacking.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

export type DotConfig = {
	Source: CharacterEntity?,
	Damage: number,
	Interval: number,
	Ticks: number,
	Trait: CombatTypes.DamageTrait?,
	-- "Ability" unless given: "Plain" for a DoT the perk ResistAbilities must not reduce.
	Style: CombatTypes.DamageStyle?,
	-- Replicated status name shown by clients (burning, poisoned...). Defaults to the effect name.
	Status: string?,
}

type Effect = {
	Kind: "Dot" | "Stun" | "Slow",
	EndsAt: number,
	NextTick: number,
	Dot: DotConfig?,
	TicksLeft: number,
}

local STEP = 0.1
local STUN_STATUS = "Stunned"

local StatusService = Knit.CreateService({
	Name = "StatusService",
	Client = {},
})

-- (target, name) when a stun starts; not when one already running is only prolonged.
StatusService.StunApplied = Signal.new() :: Signal.Signal<CharacterEntity, string>

local CombatService
local CharacterService
local AbilityService

local effects: { [CharacterEntity]: { [string]: Effect } } = {}

local function getEffects(entity: CharacterEntity): { [string]: Effect }
	local owned = effects[entity]
	if not owned then
		owned = {}
		effects[entity] = owned
	end
	return owned
end

local function remove(entity: CharacterEntity, name: string, effect: Effect)
	-- The table can be gone already: a tick of damage that removed the entity (EntityRemoving).
	local owned = effects[entity]
	if owned then
		owned[name] = nil
	end
	if effect.Kind == "Stun" then
		entity:SetRooted(name, false)
		-- Several named stuns can overlap: the shared status goes only with the last one.
		for _, other in owned or {} do
			if other.Kind == "Stun" then
				return
			end
		end
		entity:ClearStatus(STUN_STATUS)
	elseif effect.Kind == "Slow" then
		entity:SetSpeedScale(name, nil)
	else
		entity:ClearStatus((effect.Dot :: DotConfig).Status or name)
	end
end

local function update()
	local now = os.clock()
	for entity, owned in effects do
		for name, effect in owned do
			if entity.Dead then
				remove(entity, name, effect)
				continue
			end

			local dot = effect.Dot
			if dot and now >= effect.NextTick then
				effect.NextTick += dot.Interval
				effect.TicksLeft -= 1
				CombatService:Damage({
					Target = entity,
					Attacker = dot.Source,
					Amount = dot.Damage,
					Trait = dot.Trait or "Special",
					Style = dot.Style or "Ability",
					Tag = name,
				})
				if effect.TicksLeft <= 0 then
					remove(entity, name, effect)
				end
			elseif not dot and now >= effect.EndsAt then
				remove(entity, name, effect)
			end
		end
		if next(owned) == nil then
			effects[entity] = nil
		end
	end
end

function StatusService:ApplyDot(target: CharacterEntity, name: string, config: DotConfig)
	if target.Dead then
		return
	end

	local now = os.clock()
	local owned = getEffects(target)
	local existing = owned[name]
	owned[name] = {
		Kind = "Dot",
		EndsAt = now + config.Interval * config.Ticks,
		-- Refreshing keeps the running tick, so constant re-application cannot starve the damage.
		NextTick = if existing and existing.Kind == "Dot" then math.min(existing.NextTick, now + config.Interval) else now + config.Interval,
		Dot = config,
		TicksLeft = config.Ticks,
	}
	target:SetStatus(config.Status or name, true, nil, true)
end

-- Roots the target and interrupts its abilities for `duration` seconds.
function StatusService:ApplyStun(target: CharacterEntity, duration: number, name: string?)
	if target.Dead then
		return
	end

	local key = name or STUN_STATUS
	local effects = getEffects(target)
	local existing = effects[key]
	-- A shorter stun of the same kind never shortens the one already running.
	local endsAt = os.clock() + duration
	if existing and existing.Kind == "Stun" then
		endsAt = math.max(existing.EndsAt, endsAt)
	end
	effects[key] = { Kind = "Stun", EndsAt = endsAt, NextTick = 0, Dot = nil, TicksLeft = 0 }
	target:SetRooted(key, true)
	target:SetStatus(STUN_STATUS, true, nil, true)
	AbilityService:InterruptForStun(target)
	if not existing then
		StatusService.StunApplied:Fire(target, key)
	end
end

-- Multiplies walk speed by `scale` (0.1 = 10%) for `duration` seconds.
function StatusService:ApplySlow(target: CharacterEntity, name: string, scale: number, duration: number)
	if target.Dead then
		return
	end

	getEffects(target)[name] = { Kind = "Slow", EndsAt = os.clock() + duration, NextTick = 0, Dot = nil, TicksLeft = 0 }
	target:SetSpeedScale(name, scale)
end

function StatusService:Has(target: CharacterEntity, name: string): boolean
	local owned = effects[target]
	return owned ~= nil and owned[name] ~= nil
end

function StatusService:Clear(target: CharacterEntity, name: string)
	local owned = effects[target]
	local effect = owned and owned[name]
	if effect then
		remove(target, name, effect)
	end
end

function StatusService:KnitInit()
	CombatService = Knit.GetService("CombatService")
	CharacterService = Knit.GetService("CharacterService")
	AbilityService = Knit.GetService("AbilityService")
end

function StatusService:KnitStart()
	CharacterService.EntityRemoving:Connect(function(entity: CharacterEntity)
		effects[entity] = nil
	end)

	-- The only thing that ends a stun, a slow or a damage over time: an error in one tick
	-- (a damage modifier, an entity that went away) must not end the loop, or every
	-- effect applied afterwards would last for good.
	task.spawn(function()
		while true do
			task.wait(STEP)
			if next(effects) ~= nil then
				local ok, problem = pcall(update)
				if not ok then
					warn(`[StatusService] update failed: {tostring(problem)}`)
				end
			end
		end
	end)
end

return StatusService
