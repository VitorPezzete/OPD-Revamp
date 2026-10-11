--!strict
--[[
	Barrier fruit - Room (toggle): a hollow barrier centered on the user that nobody can
	walk through, in or out. Pressing again removes it.

	Side: 150 * defense affinity * (defense level / cap) studs, same on every axis.

	Collision is an invisible server copy of the authored hollow shell
	(Assets.Models.Fruits.Barrier.Power4.BarrierRoom), or six slabs when that asset is
	missing. The visible room and its 1 s grow-in are the client effect of the
	BarrierConstruct status.

	KeepThroughStun: a standing room outlives a stun of its user, as in the legacy game.
	A stunned user can neither raise nor drop one.

	Legacy problems fixed here: same as Wall (unused charge flow, room left behind on
	death). The collision is at full size at once instead of growing for a second with
	the tween: one resize instead of a server tween.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Construct = require(script.Parent._Construct)

local BASE_SIDE = 150
local MIN_SIDE = 8
-- Slab thickness of the fallback shell.
local SHELL_THICKNESS = 2

local Room = Ability.extend()

-- The legacy LocalScript waited half a second between two presses.
Room.Debounce = 0.5
Room.KeepThroughStun = true

function Room:CanBegin(): boolean
	return not self.Entity:HasStatus(Construct.StunStatus)
end

function Room:OnBegin()
	local entity = self.Entity
	if Construct.Get(entity) == "Room" then
		Construct.Clear(entity, "Room")
		return
	end

	local side = math.clamp(
		BASE_SIDE * self:GetLevelScale("Defense") * self:GetAffinity("Defense"),
		MIN_SIDE,
		Construct.MaxExtent
	)
	local size = Vector3.new(side, side, side)

	local look = entity.Root.CFrame.LookVector
	local cframe = Construct.Frame(entity.Root.Position, Vector3.new(look.X, 0, look.Z))

	local template = Construct.FindTemplate("Power4", "BarrierRoom")
	local parts = if template
		then Construct.FromTemplate(template, cframe, size)
		else Construct.Shell(cframe, size, SHELL_THICKNESS, true)

	Construct.Set(entity, "Room", cframe, size, self:GetColorString(), parts)
end

function Room:OnInterrupt()
	Construct.Clear(self.Entity, "Room")
end

return Room
