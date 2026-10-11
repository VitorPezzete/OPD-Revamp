--!strict
--[[
	Plasma fruit - Energize (toggle): run on plasma at increased walk speed.

	Speed bonus (fraction of base walk speed):
		(1 + 2.5 * melee affinity) * (melee level / cap)
	This is the formula of the legacy walk speed script (WS_Script, PlasmaRushing branch);
	the fruit script had an older "1 + 2 * affinity" version commented out.

	Legacy problems fixed here:
	- The server ran a `while PlasmaRushing` loop cloning a footprint part every 0.15 s and
	  kept two attachments in script-level variables shared by every activation, so a
	  second activation lost the first pair. The feet effects are a client effect driven
	  by the replicated status (value: fruit color string).
	- Nothing turned the state off on death or when the fruit was sealed.

	A stun does not turn it off (KeepThroughStun), as in the legacy game, where only the
	key did; a stunned user cannot press it. The walk speed is zero while rooted anyway.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "PlasmaRushing"
local SPEED_MODIFIER = "PlasmaRushing"
local STUN_STATUS = "Stunned"

local BASE_BONUS = 1
local AFFINITY_BONUS = 2.5

local Energize = Ability.extend()

Energize.KeepThroughStun = true

function Energize:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function Energize:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	local bonus = (BASE_BONUS + AFFINITY_BONUS * self:GetAffinity("Melee")) * self:GetLevelScale("Melee")
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, bonus)
	self.Entity:SetStatus(STATUS, self:GetColorString(), nil, true)
end

function Energize:OnInterrupt()
	self.Active = false
	self.Entity:SetSpeedBonus(SPEED_MODIFIER, nil)
	self.Entity:ClearStatus(STATUS)
end

return Energize
