--!strict
--[[
	Gravity fruit - Gravity Flying (toggle): the user floats, with rocks torn from the
	ground drifting up around it.

	The server only owns the state. The replicated status carries the top speed and the
	fruit colors ("<speed>|<colors>"); the owner's client flies the character and every
	client draws the rocks (Effects.Status.GravityFlying) and the aura
	(Effects.Status.GravityAura).

	Top speed. The legacy client ran, every rendered frame:
		momentum = momentum * 0.96 + direction * (40 / 9 + defense level / 50 / 9 * defense affinity)
	which settles at 25 times the added term (1 / (1 - 0.96)), so
		top speed = 25 * (40 / 9 + defense level / 450 * defense affinity) studs per second
	(111 at level 0, 167 at level 500 with affinity 2). The legacy term was also
	multiplied by CoreModule:GetBaseSpeed(): the character's "NMOD" value, or 1 without
	one. Nothing in the legacy game creates that value: it is taken as 1.

	Legacy problems fixed here:
	- The server toggled on every message and ran a `while flying` loop per press that
	  spawned the rocks; pressing twice quickly left two loops running.
	- The "flight disabler" message was debounced together with the toggle, so it could
	  be dropped and leave the user flying.
	- The body movers, the aura and the flying animation were created by the server and
	  only removed by the toggle, never on death.

	Flight disabler (Server.Modules.FlightLock, `Flight = true`): any power of the
	character that raised the legacy counter lands the user and locks the take-off for
	3 s. The legacy Gravity server never looked at the NoMovement flag, so that one does
	not stop a take-off (IsFlightBlocked(true)).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local BASE_GAIN = 40 / 9
local GAIN_PER_LEVEL = 1 / 450
-- Steady state of "momentum * 0.96 + gain" is gain / (1 - 0.96).
local GAIN_TO_SPEED = 25

local GravityFlying = Ability.extend()

GravityFlying.Flight = true

function GravityFlying:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(Shared.FlyingStatus)
		or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked(true))
end

function GravityFlying:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(Shared.FlyingStatus)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local gain = BASE_GAIN + self:GetLevel("Defense") * GAIN_PER_LEVEL * self:GetAffinity("Defense")
	local speed = math.round(gain * GAIN_TO_SPEED)
	local colors = self:GetColorString()

	self.Active = true
	entity:SetStatus(Shared.FlyingStatus, `{speed}|{colors}`, nil, true)
	Shared.SetAura(entity, Shared.FlightSource, colors)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function GravityFlying:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(Shared.FlyingStatus)
	Shared.SetAura(self.Entity, Shared.FlightSource, nil)
end

return GravityFlying
