--!strict
--[[
	Spin fruit - Copter (toggle): fly with the blades on the back and feet.

	The server only owns the state. The replicated status carries the flight speed and
	the fruit colors ("<speed>|<colors>"); the owner's client flies the character and
	every client welds the blades (Effects.Status.SpinFlying).

	Speed: the legacy client drove a BodyPosition whose power was
		P = 60 + melee level / 50 * melee affinity
	aimed 10000 studs ahead. That BodyPosition is the "FlareJet" template (D = 1250), so
	it settled at P * 10000 / 1250 = 8 * P studs per second: 480 studs/s at level 0, 640 at
	level 500 with affinity 2.

	Legacy problems fixed here:
	- The client decided when it was flying and told the server "Fly" / "Land", while
	  the server script toggled on any message: both sides could disagree for good.
	- Blades were welded on the server and only removed by the toggle, never on death
	  or when the fruit was sealed.

	Flight disabler (Server.Modules.FlightLock, `Flight = true`): any power of the
	character, of either fruit, that raised the legacy counter grounds the copter and
	locks it for 3 seconds. The legacy server also refused the copter under the
	NoMovement flag (DF Spin.server 58).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "SpinFlying"

local BASE_POWER = 60
local LEVELS_PER_POWER = 50
-- Terminal speed of the legacy BodyPosition: target distance / damping.
-- The legacy mover gives 10000 / 1250 = 8 studs/s per unit of power, but that was a 4x
-- speed-up of the copy the dump was taken from: the game's own value is a quarter of it.
local SPEED_PER_POWER = 10000 / 1250 / 4

local Copter = Ability.extend()

Copter.Flight = true

function Copter:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function Copter:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local power = BASE_POWER + self:GetLevel("Melee") / LEVELS_PER_POWER * self:GetAffinity("Melee")
	local speed = math.round(power * SPEED_PER_POWER)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function Copter:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return Copter
