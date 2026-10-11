--!strict
--[[
	Blood fruit - Blood Concentrate (toggle): the user burns its own blood to double
	the fruit. While it is on, every other Blood ability costs twice as much health and
	deals / heals / reaches twice as much (see BloodShared; each ability lists what).

	Turning it on costs 20% of max health (the listed 10%, itself doubled because the
	mode is already on when the cost is taken - the legacy behaviour, kept).
	Upkeep: 1.5% of max health every 0.5 s, starting immediately. It can kill.
	1 s between toggles.

	The mode is the BloodConcentrate status (value: fruit colors), which is how the
	sibling abilities and the aura effect know about it.

	A stun does not end the mode (KeepThroughStun), as in the legacy game, and the upkeep
	keeps running through it; a stunned user cannot toggle it. Death, seal and losing the
	fruit end it.

	Legacy problems fixed here:
	- The flag was a script global and the upkeep a `while` loop inside the remote
	  handler; turning the mode off and on within half a second left two loops running
	  and doubled the drain for good.
	- Nothing turned it off on death or seal.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BloodShared = require(script.Parent.BloodShared)

local STATUS = BloodShared.ConcentrateStatus
local STUN_STATUS = "Stunned"
local HEALTH_COST = 10
local UPKEEP_FRACTION = 0.015
local UPKEEP_INTERVAL = 0.5

local Concentrate = Ability.extend()

Concentrate.Debounce = 1
Concentrate.KeepThroughStun = true

function Concentrate:CanBegin(): boolean
	return not self.Entity:HasStatus(STUN_STATUS)
end

function Concentrate:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	BloodShared.PayHealth(entity, HEALTH_COST)

	-- Bounded by the toggle: every path that turns the mode off bumps self.Run.
	local function upkeep()
		if self.Run ~= run or entity.Dead then
			return
		end
		entity:TakeDamage(entity.MaxHealth * UPKEEP_FRACTION)
		if self.Run == run then
			task.delay(UPKEEP_INTERVAL, upkeep)
		end
	end
	upkeep()
end

function Concentrate:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return Concentrate
