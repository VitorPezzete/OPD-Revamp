--!strict
--[[
	Love fruit - Glare (hold): the user turns to face the mouse while the key is held.

	That is all the legacy power did: its client bound a "look at the mouse" step and the
	server branch read a charge and then did nothing with it (no hitbox, no stun, no
	damage). It is ported as it was: the LoveGlare status makes the owner's client face
	the aim point (Effects.Status.LoveGlare). 1 s cooldown from the release, as before.

	It cannot start while a charged power is held or firing, nor during the cooldown of
	Beam or Slave Arrow, and no charged power starts while it is held (see _Shared).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Love = require(script.Parent._Shared)

local COOLDOWN = 1
-- Cooldowns that keep Glare shut.
local OBEYS = { "Beam", "Slave Arrow" }

local Glare = Ability.extend()

function Glare:CanBegin(): boolean
	local entity = self.Entity
	return not self.Active
		and os.clock() - (self.LastEnd or -COOLDOWN) >= COOLDOWN
		and not Love.IsBusy(entity)
		and not Love.IsLocked(entity, OBEYS)
end

function Glare:OnBegin()
	self.Active = true
	self.Entity:SetStatus(Love.GLARE_STATUS, true, nil, true)
end

function Glare:OnEnd()
	if self.Active then
		self.LastEnd = os.clock()
		self:StartCooldown(COOLDOWN)
		self:OnInterrupt()
	end
end

function Glare:OnInterrupt()
	self.Active = false
	self.Entity:ClearStatus(Love.GLARE_STATUS)
end

return Glare
