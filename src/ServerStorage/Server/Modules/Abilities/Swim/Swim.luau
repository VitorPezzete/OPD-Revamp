--!strict
--[[
	Swim fruit - Swim (toggle): the body (head, torso, limbs) stops colliding with the
	world. The root part still collides, so on its own this lets the body clip into
	things; together with Dive (which releases the root) the character passes through
	walls and floors.

	It is done with a collision group, exactly like the legacy game: the property is set
	on parts that already exist and replicates by itself, so there is nothing to simulate
	and nothing for the client to render.

	As in legacy only the key itself turns it off: it stays on through a stun and through
	a seal, during which the key does nothing (the legacy client sent nothing while
	DF_Disabled was set). It shares its 0.25 s debounce with Dive (see _Shared). Death
	and losing the fruit end it.

	Legacy problems fixed here:
	- Parts were sent back to "Default" on toggle off, whatever group they had before.
	- The server required melee 50 while the client (and the ability list) said 80.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

-- `On` instead of the base class's `Active`: Ability.Destroy clears Active on every
-- interrupt, and this state survives some of them.
local STATUS = "SwimSwimming"
local BODY_PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

local Swim = Ability.extend()

Swim.KeepThroughStun = true

function Swim:CanBegin(): boolean
	return Shared.Ready(self.Entity)
end

function Swim:TurnOff()
	self.On = false

	local previous: { [BasePart]: string }? = self.PreviousGroups
	if previous then
		self.PreviousGroups = nil
		for part, group in previous do
			part.CollisionGroup = group
		end
	end
	self.Entity:ClearStatus(STATUS)
end

function Swim:OnBegin()
	Shared.Stamp(self.Entity)
	if self.On then
		self:TurnOff()
		return
	end
	self.On = true

	local previous: { [BasePart]: string } = {}
	for _, partName in BODY_PARTS do
		local part = self.Entity.Model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			previous[part] = part.CollisionGroup
			part.CollisionGroup = Shared.Group
		end
	end
	self.PreviousGroups = previous

	-- Server-side flag only: no client effect exists for it.
	self.Entity:SetStatus(STATUS, true)
end

function Swim:OnInterrupt()
	if self.On and Shared.KeepsState(self) then
		return
	end
	self:TurnOff()
end

return Swim
