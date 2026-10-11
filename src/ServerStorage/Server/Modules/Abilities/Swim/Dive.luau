--!strict
--[[
	Swim fruit - Dive (hold): the root part stops colliding with the world, so the
	character sinks into the ground. With Swim also on, nothing of the character collides
	and it goes through walls and floors.

	Same collision group as Swim (see _Shared).

	The legacy client sent a message on the press and another on the release, and the
	server TOGGLED on each one it accepted (it ignored the "Hide" / "Show" word), behind
	the 0.25 s debounce it shared with Swim. So a hold works as expected, but a tap
	shorter than 0.25 s loses its release: the dive stays on and the key is inverted
	(release dives, press surfaces) until another quick tap. Players relied on that to
	stay under without holding the key, so it is reproduced: both edges toggle, both go
	through the shared debounce. A release while the powers are sealed or the character
	is stunned was dropped by the legacy client as well (so being stunned while holding
	the key also leaves the dive on).

	Like Swim, nothing but the key turns it off (stun and seal leave it as it is).

	Legacy problems fixed here:
	- The root was sent back to "Default" instead of the group it had before.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local STATUS = "SwimDiving"

local Dive = Ability.extend()

Dive.KeepThroughStun = true

function Dive:TurnOff()
	self.On = false

	local previous: string? = self.PreviousGroup
	if previous then
		self.PreviousGroup = nil
		self.Entity.Root.CollisionGroup = previous
	end
	self.Entity:ClearStatus(STATUS)
end

function Dive:Toggle()
	Shared.Stamp(self.Entity)
	if self.On then
		self:TurnOff()
		return
	end
	self.On = true

	local root = self.Entity.Root
	self.PreviousGroup = root.CollisionGroup
	root.CollisionGroup = Shared.Group

	-- Server-side flag only: no client effect exists for it.
	self.Entity:SetStatus(STATUS, true)
end

function Dive:CanBegin(): boolean
	return Shared.Ready(self.Entity)
end

function Dive:OnBegin()
	self:Toggle()
end

function Dive:OnEnd()
	-- Releases reach the ability even when a press would not: apply the legacy gates here.
	if not Shared.Ready(self.Entity) then
		return
	end
	self:Toggle()
end

function Dive:OnInterrupt()
	if self.On and Shared.KeepsState(self) then
		return
	end
	self:TurnOff()
end

return Dive
