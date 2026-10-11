--!strict
--[[
	Shared by Swim and Dive: the collision group and the input debounce.

	The legacy server script had ONE 0.25 s debounce for both powers and for every message
	(Swim press, Dive press, Dive release): whatever arrived within 0.25 s of the last
	accepted message was dropped. The time of that message is kept on the entity, since
	sibling abilities do not see each other's objects.
]]
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local Shared = {}

Shared.Group = "SwimNoCollide"
Shared.Debounce = 0.25

local STAMP = "SwimLastInput"

if not PhysicsService:IsCollisionGroupRegistered(Shared.Group) then
	PhysicsService:RegisterCollisionGroup(Shared.Group)
end
PhysicsService:CollisionGroupSetCollidable(Shared.Group, "Default", false)
PhysicsService:CollisionGroupSetCollidable(Shared.Group, Shared.Group, false)

-- The legacy client sent nothing while DF_Disabled was set: a seal, or a stun (the
-- legacy stun set that flag for its whole length).
function Shared.Blocked(entity: CharacterEntity): boolean
	return entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled) or entity:HasStatus("Stunned")
end

function Shared.Ready(entity: CharacterEntity): boolean
	if Shared.Blocked(entity) then
		return false
	end
	local last = entity:GetStatus(STAMP)
	return type(last) ~= "number" or os.clock() - last >= Shared.Debounce
end

function Shared.Stamp(entity: CharacterEntity)
	entity:SetStatus(STAMP, os.clock())
end

--[[
	Nothing in legacy ever turned the powers off except their own key: a sealed or
	stunned character stayed intangible. True when an interrupt is only that (the
	character lives and still owns the fruit) and the state must be left alone.
]]
function Shared.KeepsState(ability: any): boolean
	local entity: CharacterEntity = ability.Entity
	if entity.Dead or not entity.Model.Parent then
		return false
	end
	if not entity:HasStatus(AbilityConfig.Status.AbilitiesDisabled) then
		return false
	end
	return ability.Services.Fruit:HasFruit(ability.Player, "Swim") == true
end

return Shared
