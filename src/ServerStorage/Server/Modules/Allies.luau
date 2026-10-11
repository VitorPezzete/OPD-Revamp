--!strict
--[[
	Who is on whose side, in one place.

	A side is CharacterEntity.Team (the empty string = none): crew-war teams in the main
	game (WorldEventService), and in the raid place one team for every player
	(RaidRunService puts each player's character on Allies.RaidTeam; what a player summons
	takes its owner's team by itself, see Hobby).

	Two rules, by how much they forbid:

	- SameSide: the old rule, everywhere. CombatService refuses damage between two
	  characters of one team. Stuns and the like were never covered by it.
	- Spares: the raid rule. In the raid place a player never harms or hinders another
	  one: no damage, no damage over time, no stun, slow, knockback, grab or curse. Those
	  have no single function they all go through - a stun does not know who caused it -
	  but they all start by FINDING a target, and that is where the rule is applied: an
	  ally is never found by an attacker's Hitbox query, never met by its Projectile, and
	  the few abilities that look for targets by themselves ask Spares too. CombatService
	  stays as the last word on health.

	What helps is not an attack: a query that looks for characters to heal or strengthen
	says so (Hitbox's `friendly` argument) and still finds allies.

	Spares is the raid's only: in the main game team mates of a crew war can still be
	stunned by each other, as they always could. Dropping the place test below would
	extend the full protection to every team.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local IS_RAID = PlaceConfig.Role == "Raid"

local Allies = {}

-- The team of every player in the raid place.
Allies.RaidTeam = "Raid"

-- Two characters of one team. No damage passes between them, in any place.
function Allies.SameSide(first: CharacterEntity, second: CharacterEntity): boolean
	return first.Team ~= "" and first.Team == second.Team
end

--[[
	Whether nothing `attacker` does may reach `target` (see the header). False without an
	attacker: what nobody owns (a hazard of the map) spares no one.
]]
function Allies.Spares(attacker: CharacterEntity?, target: CharacterEntity): boolean
	return IS_RAID and attacker ~= nil and attacker ~= target and Allies.SameSide(attacker, target)
end

return table.freeze(Allies)
