--!strict
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

-- What the damage is made of: decides immunities and haki resistance.
export type DamageTrait = "Melee" | "Sword" | "Special" | "Haki" | "Bleed"
-- Where the damage came from: decides which resistance perk applies.
-- "Plain": damage the legacy game dealt without naming a style, which no resistance
-- perk (ResistWeapons / ResistAbilities) reduced.
export type DamageStyle = "Weapon" | "Ability" | "Environment" | "Plain"

export type DamageRequest = {
	Target: CharacterEntity.CharacterEntity,
	Attacker: CharacterEntity.CharacterEntity?,
	Amount: number,
	Trait: DamageTrait,
	Style: DamageStyle,
	Dodgeable: boolean?,
	-- Free-form label for effects that react to specific hits (e.g. "Slash").
	Tag: string?,
}

-- Mutable state handed to every modifier, in priority order.
export type DamageContext = {
	Target: CharacterEntity.CharacterEntity,
	Attacker: CharacterEntity.CharacterEntity?,
	TargetData: PlayerData.PlayerData?,
	AttackerData: PlayerData.PlayerData?,
	Amount: number,
	-- Portion that ignores every mitigation step.
	TrueAmount: number,
	Trait: DamageTrait,
	Style: DamageStyle,
	Dodgeable: boolean,
	Tag: string?,
	Cancelled: boolean,
	CancelReason: string?,
}

export type DamageModifier = {
	Name: string,
	-- Lower runs first.
	Priority: number,
	Apply: (context: DamageContext) -> (),
}

return {}
