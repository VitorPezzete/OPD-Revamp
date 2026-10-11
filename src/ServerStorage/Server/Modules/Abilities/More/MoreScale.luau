--!strict
--[[
	More fruit - shared size logic of Resize, Resize Other, Restore All and the passive.
	Not an ability: AbilityService only requires modules named after a FruitConfig ability.

	Size = 1 + 2 * (melee level / cap) * defense affinity      (1x to 5x)

	State lives on the resized character, never on an ability object, because the three
	abilities are separate objects and the victims outlive a stun of the caster:
	- "MoreMored"   (replicated) = the size multiplier. The legacy Mored BoolValue plus
	  its Quantity child; it also drove the "You are giant!" status icon.
	- "MoreMoredBy" (server only) = the entity that resized it, which is what Restore All
	  and the caster's death look for (the legacy "hobbies" table).

	Model:ScaleTo runs on the server on purpose: the size is gameplay state (collision,
	reach), not a visual, and it creates no instance.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local MoreScale = {}

MoreScale.Status = "MoreMored"
MoreScale.OwnerStatus = "MoreMoredBy"

function MoreScale.GetSize(levelScale: number, affinity: number): number
	return 1 + 2 * levelScale * affinity
end

function MoreScale.IsResized(target: CharacterEntity): boolean
	return target:HasStatus(MoreScale.Status)
end

function MoreScale.Apply(target: CharacterEntity, size: number, owner: CharacterEntity)
	if target.Dead or size ~= size or size <= 0 or target.Model.Parent == nil then
		return
	end
	target:SetStatus(MoreScale.Status, size, nil, true)
	target:SetStatus(MoreScale.OwnerStatus, owner)
	target.Model:ScaleTo(size)
end

function MoreScale.Restore(target: CharacterEntity)
	if not MoreScale.IsResized(target) then
		return
	end
	target:ClearStatus(MoreScale.Status)
	target:ClearStatus(MoreScale.OwnerStatus)
	if target.Model.Parent ~= nil then
		target.Model:ScaleTo(1)
	end
end

-- Restores every character resized by `owner`; the owner itself only when asked.
function MoreScale.RestoreOwnedBy(owner: CharacterEntity, includeOwner: boolean)
	local entities: { [Model]: CharacterEntity } = Knit.GetService("CharacterService"):GetEntities()
	for _, target in entities do
		if target:GetStatus(MoreScale.OwnerStatus) == owner and (includeOwner or target ~= owner) then
			MoreScale.Restore(target)
		end
	end
end

return MoreScale
