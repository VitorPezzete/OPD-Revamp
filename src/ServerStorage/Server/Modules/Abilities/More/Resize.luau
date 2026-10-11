--!strict
--[[
	More fruit - Resize (toggle): the user grows to
		1 + 2 * (melee level / cap) * defense affinity      times its size,
	and back to normal on the next press.

	The formula is the legacy one as written: it scales with the MELEE level although the
	ability is gated by Defense (the server script checked "MeleeLvl >= 50" for every
	power). Swap the skill below if Defense was meant.

	As in the legacy game the press also undoes a size given by somebody else's
	Resize Other: the toggle looks at the character's state, not at who set it.

	Nothing but the key shrinks the user, as in the legacy game: not a stun, not a seal
	(the key is simply dead meanwhile). Death and losing the fruit do (Passives/More).

	The legacy client asked for Defense 50 and the legacy server for Melee 50: both are
	needed (FruitConfig holds the first, CanBegin the second).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local MoreScale = require(script.Parent.MoreScale)

local STUN_STATUS = "Stunned"
local MELEE_REQUIREMENT = 50

local Resize = Ability.extend()

Resize.KeepThroughStun = true

function Resize:CanBegin(): boolean
	-- KeepThroughStun also lets presses through during a stun.
	return not self.Entity:HasStatus(STUN_STATUS) and self:GetLevel("Melee") >= MELEE_REQUIREMENT
end

function Resize:OnBegin()
	local entity = self.Entity
	if MoreScale.IsResized(entity) then
		self.Active = false
		MoreScale.Restore(entity)
		return
	end

	self.Active = true
	MoreScale.Apply(entity, MoreScale.GetSize(self:GetLevelScale("Melee"), self:GetAffinity("Defense")), entity)
end

-- A seal or a stun leaves the size alone; Passives/More restores it on death / fruit loss.
function Resize:OnInterrupt()
	self.Active = false
end

return Resize
