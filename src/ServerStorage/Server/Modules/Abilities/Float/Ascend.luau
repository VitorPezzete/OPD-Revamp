--!strict
--[[
	Float fruit - Ascend (hold): while floating, climbs at 50 studs/s for as long as the
	key is held. Does nothing unless Float is active.

	The flag is read every frame by the owner's hover (Effects/Status/FloatFloating), so
	it has no effect module of its own.

	Legacy problem fixed here: the "charging" bookkeeping it reused could get stuck when
	a release was lost, after which Ascend never started again.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local FLOATING = "FloatFloating"
local ASCENDING = "FloatAscending"

local Ascend = Ability.extend()

-- A hold: a quick second press must not be swallowed (the legacy one had no debounce).
Ascend.Debounce = 0

function Ascend:CanBegin(): boolean
	return self.Entity:HasStatus(FLOATING)
end

function Ascend:OnBegin()
	self.Entity:SetStatus(ASCENDING, true, nil, true)
end

function Ascend:OnEnd()
	self.Entity:ClearStatus(ASCENDING)
end

function Ascend:OnInterrupt()
	self.Entity:ClearStatus(ASCENDING)
end

return Ascend
