--!strict
--[[
	Flare fruit - Jet (toggle): fly on two jets of fire from the legs.

	The server only owns the state. The replicated status carries the flight speed and
	the fruit colors ("<speed>|<colors>"); the owner's client flies the character and
	every client draws the leg fire (Effects.Status.FlareFlying).

	Speed: the legacy client drove a BodyPosition (Resources.FlareJet, MaxForce 4e6 on
	every axis, damping D = 1250 as authored in the asset) whose power it set every frame:
		P = 60 + melee level / 50 * melee affinity
	and whose goal it kept 10000 studs away from the torso: along the walk direction on
	X / Z, and by camera pitch * forwardness on Y. A BodyPosition pulls with
	P * distance and brakes with D * velocity, so each axis settles where the two cancel:
		velocity = P * 10000 / 1250 = 8 studs/s per unit of power, per axis
	(480 studs/s at level 0, 560 at level 500 with affinity 1, 640 with affinity 2), far
	below what the 4e6 force allows, reached at once. SPEED_PER_POWER is that ratio; the
	owner's client applies it per axis the same way (Effects.Status.FlareFlying). With no
	walk input the goal was the torso itself: the character hovers. The legacy "base
	speed" multiplier of the client CoreModule read a value (NMOD) nothing ever created,
	so it was always 1.

	Legacy problems fixed here:
	- The client decided when it was flying and told the server "Fly" / "Land"; a "Land"
	  without a "Fly" drove the shared Fly counter below zero.
	- Leg particles were server instances only removed by "Land", never on death.

	Flight disabler (Server.Modules.FlightLock, `Flight = true`): any power of the
	character that raised the legacy counter lands the jet and locks it for 3 s. The
	legacy server also refused the take-off under NoMovement (DF FlareNew.server 136).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "FlareFlying"

local BASE_POWER = 60
local POWER_PER_LEVEL = 1 / 50
-- The legacy mover gives 10000 / 1250 = 8 studs/s per unit of power, but that was a 4x
-- speed-up of the copy the dump was taken from: the game's own value is a quarter of it.
local SPEED_PER_POWER = 10000 / 1250 / 4

local Jet = Ability.extend()

Jet.Flight = true

function Jet:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function Jet:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local power = BASE_POWER + self:GetLevel("Melee") * POWER_PER_LEVEL * self:GetAffinity("Melee")
	local speed = math.round(power * SPEED_PER_POWER)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function Jet:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return Jet
