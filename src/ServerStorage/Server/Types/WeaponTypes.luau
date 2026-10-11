--!strict
--[[
	Contract between AttackService and the per-weapon modules in Server.Modules.Weapons.

	A weapon only gets a module when it does something the config cannot describe: a
	damage formula of its own, an effect on hit, or a special attack that is not a thrown
	slash. Every hook is optional.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type CharacterEntity = CharacterEntity.CharacterEntity

-- Built by AttackService for one validated attack or special. Never comes from the client.
export type WeaponContext = {
	Player: Player,
	Entity: CharacterEntity,
	Data: PlayerData.PlayerData,
	Tool: Tool,
	WeaponName: string,
	Weapon: WeaponConfig.WeaponDefinition,
	-- Level of the weapon slot's skill.
	Level: number,
	-- Armament haki was on when the attack started.
	Haki: boolean,
	-- 2 with armament haki, else 1.
	HakiMultiplier: number,
	-- BuffWeapons perk factor.
	PerkMultiplier: number,
	-- Validated aim point (finite, within AbilityConfig.MaxAimDistance of the character).
	Aim: Vector3,
	-- Knit services: Combat, Character, Status, Effect, Haki, Fruit, Ability, Notify, Attack.
	Services: { [string]: any },
	-- The character is alive and still holds this weapon.
	IsHolding: (self: WeaponContext) -> boolean,
}

export type WeaponBehaviour = {
	-- Extra gate on swings and specials (e.g. owner-only weapons).
	CanUse: ((context: WeaponContext) -> boolean)?,
	-- Replaces the base damage of a basic attack (before haki and perk).
	GetDamage: ((context: WeaponContext, base: number) -> number)?,
	-- After each character hit by a basic attack.
	OnHit: ((context: WeaponContext, target: CharacterEntity, dealt: number) -> ())?,
	-- Extra params for the client effect of the generic thrown slash.
	SlashParams: ((context: WeaponContext) -> { [string]: any }?)?,
	-- After each character hit by the generic thrown slash.
	OnSlashHit: ((context: WeaponContext, target: CharacterEntity) -> ())?,
	-- Special attack. Return false when nothing happened: the cooldown is given back.
	Special: ((context: WeaponContext) -> boolean?)?,
}

return {}
