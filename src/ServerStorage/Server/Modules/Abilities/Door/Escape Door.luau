--!strict
--[[
	Door fruit - Escape Door: the user steps through a door and comes out at the aimed
	point.

	DESIGNED, NOT PORTED (see Door Strike: the legacy Door fruit had no server logic and
	no assets). The legacy client sent only the mouse position on key release; the gate
	is Defense 75. Placeholder numbers:

		range:    100 * defense affinity studs (100-200); a further aim point is shortened
		          to that distance along the same line
		arrival:  3 studs above the aimed point (root height), facing the way travelled
		cooldown: 5 s
		Cannot be used while rooted / stunned (so not out of Dimensional Trap) or seated.

	The door goes through walls on purpose: the destination is not checked for line of
	sight, only for distance. The teleport itself is done by the server.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local RANGE_PER_AFFINITY = 100
local MIN_DISTANCE = 4
local ARRIVAL_HEIGHT = 3
-- How far in front of the user each door stands.
local DOOR_DISTANCE = 2

local EscapeDoor = Ability.extend()

EscapeDoor.Debounce = 5

function EscapeDoor:CanBegin(input: Ability.AbilityInput): boolean
	local entity = self.Entity
	if entity:IsRooted() or entity.Humanoid.Sit then
		return false
	end
	return (input.AimPosition - entity.Root.Position).Magnitude >= MIN_DISTANCE
end

function EscapeDoor:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local origin = entity.Root.Position

	local offset = input.AimPosition - origin
	local range = RANGE_PER_AFFINITY * self:GetAffinity("Defense")
	if offset.Magnitude > range then
		offset = offset.Unit * range
	end

	local flat = Vector3.new(offset.X, 0, offset.Z)
	local facing = if flat.Magnitude > 0.1 then flat.Unit else entity.Root.CFrame.LookVector
	local destination = origin + offset + Vector3.new(0, ARRIVAL_HEIGHT, 0)

	local entryPosition = origin + facing * DOOR_DISTANCE
	self:PlayEffect("DoorPanel", entryPosition, { CFrame = CFrame.lookAt(entryPosition, entryPosition + facing) })

	self.Services.Character:Teleport(entity, CFrame.lookAt(destination, destination + facing))

	-- The exit door is behind the user, who walks out of it.
	local exitPosition = destination - facing * DOOR_DISTANCE
	self:PlayEffect("DoorPanel", exitPosition, { CFrame = CFrame.lookAt(exitPosition, exitPosition + facing) })
end

return EscapeDoor
