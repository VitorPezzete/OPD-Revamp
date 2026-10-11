--!strict
--[[
	Hobby fruit - Target: every toy of the user chases the aimed character and attacks it.

	A toy within 10 studs of the target hits it at most every 0.5 s:
	- player toy:  its own melee level, "Melee"; above haki level 200 it is doubled and
	               dealt as "Haki";
	- NPC toy:     the damage and trait of that enemy (EnemyConfig);
	- toy soldier: what Claim gave it.
	Hits are "Ability" damage, not dodgeable, credited to the Hobby user. The order ends
	when the target dies or despawns, when another order is given, when the user is
	interrupted, or after 120 s.

	Legacy problems fixed here ("Hobby Exploits"):
	- The client sent the target *instance* and the server used it unchecked (any part
	  with a Parent that had a "Spawned" child, at any distance). The target is now the
	  character closest to the validated aim point, picked on the server.
	- Each toy ran a PathfindingService:ComputeAsync every Heartbeat for as long as the
	  target lived; it is one 4 Hz tick per user that walks the toys straight at the
	  target (no pathfinding: toys do not route around obstacles any more).
	- The order counter was one script-level number bumped by every remote call.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Toys = require(script.Parent._Toys)

type CharacterEntity = CharacterEntity.CharacterEntity

-- How far from the aim point a character may be and still count as "aimed at".
local AIM_RADIUS = 8

local Target = Ability.extend()

function Target:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity

	-- The user's own toys are not valid targets.
	local candidates: { CharacterEntity } = {}
	for _, candidate in Hitbox.Sphere(input.AimPosition, AIM_RADIUS, entity) do
		if Toys.GetOwner(candidate) ~= entity then
			table.insert(candidates, candidate)
		end
	end

	local target = Hitbox.Closest(candidates, input.AimPosition)
	if target then
		Toys.Attack(entity, target)
	end
end

function Target:OnInterrupt()
	Toys.Halt(self.Entity)
end

return Target
