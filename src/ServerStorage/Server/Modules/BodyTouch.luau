--!strict
--[[
	Body abilities carried by a melee-type power of the character's OTHER fruit.

	Legacy: the Gum server script (DF Gum.server 81-188, the only fruit script that did
	this) looked, at every Pistol / Bazooka / Gatling request, at the "body" flags of the
	character - which could only belong to its other fruit - and picked ONE extra effect,
	in this order:
		UsingMagmaBody, UsingCandyBody, UsingSnowBody, SmeltBody, HotBody,
		UsingVenomDemon, UsingVenomBody, UsingVampireHZ
	Every character the punch then hit received that effect right after the punch damage
	(and after the Bazooka push), whether or not the punch itself had been dodged or
	negated. With b = defense affinity of the body's fruit, s = defense level / cap:
		Magma       the PUNCH is multiplied by b and becomes Special (before haki), and
		            the victim burns: 100 * b per tick (no level term here) for 20 s
		Candy       CandyTouched for 3 hits + 50 * b * s Sword damage (x2, Haki with haki)
		Snow        SnowTouched: floor(10 * b) hits of 200 * b * s (no contact damage)
		Smelt       150 * b * s Special damage (x2, Haki with haki)
		Hot         150 * b * s Special damage (x2, Haki with haki)
		VenomDemon  VenomDoT "Slow":   floor(10 * b) hits of 800 * b * s
		Venom       VenomDoT "Normal": floor(10 * b) hits of 350 * b * s
		Vampire     the puncher is healed by the punch damage (after haki), up to max
	The extra damage was requested like the punch: style "Ability", dodgeable, by the
	puncher. None of the per-fruit exceptions of the bodies' own contact code applied.

	Here each of those abilities registers what it does to a punched character while it
	is on (Set in OnBegin, Set(..., nil) in OnInterrupt) and Abilities/Gum/_Shared asks
	for the one that applies (Get) when a punch is thrown. The numbers stay in the body's
	own file, next to its normal contact effect.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

type CharacterEntity = CharacterEntity.CharacterEntity

export type BodyName = "Magma" | "Candy" | "Snow" | "Smelt" | "Hot" | "VenomDemon" | "Venom" | "Vampire"

export type Punch = {
	-- The ability that threw the punch: extra damage is dealt through it (by the puncher).
	Ability: any,
	-- Damage the punch asked for, after the body's own ModifyDamage and after haki.
	Damage: number,
	-- Armament haki was on when the punch was thrown.
	Haki: boolean,
}

export type Body = {
	-- Changes the punch itself, before haki (Magma only).
	ModifyDamage: ((damage: number, trait: CombatTypes.DamageTrait) -> (number, CombatTypes.DamageTrait))?,
	-- Runs for every character the punch hits, after its damage and push.
	OnHit: ((target: CharacterEntity, punch: Punch) -> ())?,
}

-- The legacy if / elseif chain: the first one that is on wins.
local ORDER: { BodyName } = { "Magma", "Candy", "Snow", "Smelt", "Hot", "VenomDemon", "Venom", "Vampire" }

-- Weak keys: a character that is gone takes its entries with it.
local bodies: { [CharacterEntity]: { [string]: Body } } = setmetatable({}, { __mode = "k" }) :: any

local BodyTouch = {}

-- Registers (or, with nil, removes) what `name` does to characters punched by `entity`.
function BodyTouch.Set(entity: CharacterEntity, name: BodyName, body: Body?)
	local own = bodies[entity]
	if not own then
		if not body then
			return
		end
		own = {}
		bodies[entity] = own
	end
	own[name] = body
	if next(own) == nil then
		bodies[entity] = nil
	end
end

-- The body effect a punch thrown by `entity` right now carries, if any.
function BodyTouch.Get(entity: CharacterEntity): Body?
	local own = bodies[entity]
	if not own then
		return nil
	end
	for _, name in ORDER do
		local body = own[name]
		if body then
			return body
		end
	end
	return nil
end

return BodyTouch
