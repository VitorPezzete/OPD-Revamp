--!strict
--[[
	Barrier fruit - Wall (toggle): a square slab 10 studs away towards the aim point,
	facing the user. Pressing again removes it.

	Side:      defense level * defense affinity studs (yes, studs per level: a maxed user
	           raises a wall hundreds of studs wide), 8 studs thick.
	Position:  root + 10 studs along the direction to the aim point.

	Collision is one invisible anchored part on the server; the visible wall (and its
	0.5 s grow-in) is the client effect of the BarrierConstruct status.

	KeepThroughStun: a standing wall outlives a stun of its user, as in the legacy game.
	A stunned user can neither raise nor drop one.

	Legacy problems fixed here:
	- The server took the wall's position from a CFrame sent by the client. It is now
	  derived from the validated aim point.
	- The ability went through the generic "charge" remote flow (press, then release)
	  although the charge was never used; it now acts on the press.
	- The wall stayed in the world after the user died until a separate cleanup script
	  found it; it now goes through OnInterrupt.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Construct = require(script.Parent._Construct)

local DISTANCE = 10
local THICKNESS = 8

local Wall = Ability.extend()

Wall.KeepThroughStun = true

function Wall:CanBegin(): boolean
	return not self.Entity:HasStatus(Construct.StunStatus)
end

function Wall:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	if Construct.Get(entity) == "Wall" then
		Construct.Clear(entity, "Wall")
		return
	end

	local rootPosition = entity.Root.Position
	local offset = input.AimPosition - rootPosition
	local direction = if offset.Magnitude > 1e-3 then offset.Unit else entity.Root.CFrame.LookVector

	local side = math.clamp(self:GetLevel("Defense") * self:GetAffinity("Defense"), 1, Construct.MaxExtent)
	local size = Vector3.new(side, side, THICKNESS)
	local cframe = Construct.Frame(rootPosition + direction * DISTANCE, -direction)

	Construct.Set(entity, "Wall", cframe, size, self:GetColorString(), Construct.Block(cframe, size))
end

function Wall:OnInterrupt()
	Construct.Clear(self.Entity, "Wall")
end

return Wall
