--!strict
--[[
	Venom fruit - the poison every ability of the fruit applies (not an ability itself).

	Legacy `VenomDoT`: a BoolValue with DoT / Hits / Model / PlayerId children and a
	control script in every character and enemy. One application carried:
	- damage per hit  = base * (level / cap) * affinity;
	- number of hits  = floor(hits * (level / cap) * affinity)  (the "hit counter");
	- a speed: Fast / Normal / Slow = a hit every 0.1 / 0.4 / 0.6 s on a player and
	  every 0.2 / 0.6 / 1.25 s on an NPC (the enemy copy of the script was slower).
	A new application replaced the running one.

	Timing, as the legacy control script ran it: the effect shows at once, the first hit
	lands 0.25 s after the application and the others follow one interval apart; an
	application made while that 0.25 s is running only replaces the numbers of the one
	about to start; the hits of an older application keep coming until the new one
	starts. StatusService:ApplyDot counts the hits after the first one (its own first
	tick comes one interval after it is applied, which is exactly the second hit).

	A caster can poison the same victim at most once per second, whatever the ability
	(the legacy `partcd` table, which was never cleaned and was keyed by the Touched
	part's parent, accessories included).

	Venom and Luck owners still get the effect but its hits do nothing to them: see
	DamageModifiers.VenomDotImmunity (and LuckDotImmunity).

	Fixed: the legacy control script indexed `attacker.Character` without checking it
	and broke for good when the poisoner had left.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)

export type Speed = "Fast" | "Normal" | "Slow"

local Shared = {}

Shared.DOT = "VenomDoT"
-- Set by Venom Demon; every other ability of the fruit is stronger while it is on.
Shared.DEMON_STATUS = "VenomDemon"
-- Replicated while the owner must keep facing its aim (Effects.Status.VenomAiming).
Shared.AIM_STATUS = "VenomAiming"

local REAPPLY_COOLDOWN = 1
-- Legacy `task.wait(.25)` at the top of the control script.
local FIRST_HIT_DELAY = 0.25

local PLAYER_INTERVAL: { [Speed]: number } = { Fast = 0.1, Normal = 0.4, Slow = 0.6 }
local NPC_INTERVAL: { [Speed]: number } = { Fast = 0.2, Normal = 0.6, Slow = 1.25 }

-- caster entity -> victim entity -> os.clock() of the last application. Weak keys on
-- both levels: entities that are gone are forgotten without any bookkeeping.
local lastApplied: { [any]: { [any]: number } } = setmetatable({}, { __mode = "k" }) :: any

type Application = {
	Ability: any,
	Damage: number,
	Hits: number,
	Interval: number,
}

-- victim entity -> the application whose first hit is due (weak keys).
local starting: { [any]: Application } = setmetatable({}, { __mode = "k" }) :: any
-- victim entity -> token of the application that last started, for the one-hit case.
local running: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local function start(target: any)
	local application = starting[target]
	starting[target] = nil
	if not application or target.Dead or not target.Spawned then
		return
	end

	local ability = application.Ability
	local status = ability.Services.Status
	local token = {}
	running[target] = token

	-- Drops what is left of an older application, so the new hits are spaced from now.
	status:Clear(target, Shared.DOT)
	if application.Hits > 1 then
		status:ApplyDot(target, Shared.DOT, {
			Source = ability.Entity,
			Damage = application.Damage,
			Interval = application.Interval,
			Ticks = application.Hits - 1,
			Trait = "Special",
		})
	else
		-- A single hit: the effect still lasts one interval after it.
		target:SetStatus(Shared.DOT, true, nil, true)
		task.delay(application.Interval, function()
			if running[target] == token and not starting[target] and not status:Has(target, Shared.DOT) then
				target:ClearStatus(Shared.DOT)
			end
		end)
	end

	-- The first hit, dealt exactly like a tick of the effect (same tag: immunities).
	ability.Services.Combat:Damage({
		Target = target,
		Attacker = ability.Entity,
		Amount = application.Damage,
		Trait = "Special",
		Style = "Ability",
		Tag = Shared.DOT,
	})
end

function Shared.IsDemon(entity: any): boolean
	return entity:HasStatus(Shared.DEMON_STATUS)
end

--[[
	Poisons `target`. `skill` is the stat the ability scales with (its level and its
	affinity). Returns false when the one-second rule refused it.
]]
function Shared.Poison(
	ability: any,
	target: any,
	baseDamage: number,
	baseHits: number,
	skill: "Sniper" | "Defense",
	speed: Speed
): boolean
	local caster = ability.Entity
	if target == caster or target.Dead or not target.Spawned then
		return false
	end

	local perCaster = lastApplied[caster]
	if not perCaster then
		perCaster = setmetatable({}, { __mode = "k" }) :: any
		lastApplied[caster] = perCaster
	end
	local now = os.clock()
	if now - (perCaster[target] or 0) < REAPPLY_COOLDOWN then
		return false
	end
	perCaster[target] = now

	local factor = (ability:GetLevel(skill) / StatConfig.Caps[skill]) * ability:GetAffinity(skill)
	Shared.Apply(ability, target, baseDamage * factor, math.floor(baseHits * factor), speed)
	return true
end

--[[
	The application itself, with the final numbers: `hits` hits of `damage`. No
	one-second rule. Poison goes through it; so does the poison a Gum punch carries
	(Modules.BodyTouch), whose legacy numbers did not follow Poison's scaling.
]]
function Shared.Apply(ability: any, target: any, damage: number, hits: number, speed: Speed)
	if target == ability.Entity or target.Dead or not target.Spawned then
		return
	end
	if hits < 1 then
		-- Legacy: zero hits ended the effect at once.
		return
	end

	local pending = starting[target] ~= nil
	starting[target] = {
		Ability = ability,
		Damage = damage,
		Hits = hits,
		Interval = if target.Player then PLAYER_INTERVAL[speed] else NPC_INTERVAL[speed],
	}
	if not pending then
		-- Shown at once (legacy `VenomDoT.Value = true`), unless an older one already shows.
		if not target:HasStatus(Shared.DOT) then
			target:SetStatus(Shared.DOT, true, nil, true)
		end
		task.delay(FIRST_HIT_DELAY, start, target)
	end
end

return Shared
