--!strict
--[[
	Snow fruit - Snow Angel (toggle): fly on two wings of snow.

	Same design as Hot's Nose Jet: the server only owns the state. The replicated status
	carries the top speed and the fruit colors ("<speed>|<colors>"); the owner's client
	flies the character and every client draws the wings (Effects.Status.SnowFlying).

	Top speed. The legacy client ran, every rendered frame:
		momentum = momentum * 0.96 + direction * (50 / 9 + defense level / 50 / 9 * defense affinity)
	which settles at 25 times the added term, so
		top speed = 25 * (50 / 9 + defense level / 450 * defense affinity) studs per second
	(139 at level 0, 194 at level 500 with affinity 2). The legacy term was also
	multiplied by CoreModule:GetBaseSpeed(), which is always 1. The affinity is the one
	the legacy client read: always the defense affinity of fruit slot 1 (both of its
	branches used DFT1Defense), whichever slot holds the Snow fruit.

	The flight ends when toggled, when the character sits, on interrupt (stun, seal,
	death) and when any power of the character that raised the legacy "flight disabler"
	is used, which also locks it for 3 s (Server.Modules.FlightLock, `Flight = true`).
	The legacy server also refused the take-off under NoMovement (DF Snow.server 686).
	0.5 s between two toggles, as in the legacy client.

	Legacy problems fixed here:
	- `flying` was a script-level flag toggled by any message with a non-nil second
	  argument, so disabler messages could decrement the shared Fly counter below zero.
	- Wings, body movers and a Heartbeat connection were created by the server and only
	  removed by the toggle, never on death.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local SnowShared = require(script.Parent.SnowShared)

local STATUS = SnowShared.FlightStatus

local BASE_GAIN = 50 / 9
local GAIN_PER_LEVEL = 1 / 450
-- Steady state of "momentum * 0.96 + gain" is gain / (1 - 0.96).
local GAIN_TO_SPEED = 25

local SnowAngel = Ability.extend()

SnowAngel.Debounce = 0.5
SnowAngel.Flight = true

function SnowAngel:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function SnowAngel:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local affinity = self.Context.Data.Data.Affinities.DF1.Defense
	local gain = BASE_GAIN + self:GetLevel("Defense") * GAIN_PER_LEVEL * affinity
	local speed = math.round(gain * GAIN_TO_SPEED)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function SnowAngel:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return SnowAngel
