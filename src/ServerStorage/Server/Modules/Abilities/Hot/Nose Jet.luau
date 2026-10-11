--!strict
--[[
	Hot fruit - Nose Jet (toggle): fly head first on two jets of heat.

	The server only owns the state. The replicated status carries the top speed and the
	fruit colors ("<speed>|<colors>"); the owner's client flies the character and every
	client draws the jets (Effects.Status.HotFlying).

	Top speed. The legacy client ran, every rendered frame:
		momentum = momentum * 0.96 + direction * (50 / 9 + defense level / 50 / 9 * defense affinity)
	which settles at 25 times the added term (1 / (1 - 0.96)), so
		top speed = 25 * (50 / 9 + defense level / 450 * defense affinity) studs per second
	(139 at level 0, 194 at level 500 with affinity 2). The client reproduces the same
	build-up per second instead of per frame, so it no longer depends on the frame rate.

	Legacy problems fixed here:
	- The server toggled on every message, and the "flight disabler" message took the
	  landing branch even when not flying, decrementing the shared Fly counter below zero.
	- Jets, body movers and the flying animation were created by the server and only
	  removed by the toggle, never on death.
	- Coloring the second jet assigned a Color3 to a ParticleEmitter.Color and threw.

	Flight disabler (Server.Modules.FlightLock, `Flight = true`): any power of the
	character that raised the legacy counter lands the jet and locks it for 3 s. The
	legacy server also refused the take-off under the NoMovement flag (DF Hot.server 157).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "HotFlying"

local BASE_GAIN = 50 / 9
local GAIN_PER_LEVEL = 1 / 450
-- Steady state of "momentum * 0.96 + gain" is gain / (1 - 0.96).
local GAIN_TO_SPEED = 25

local NoseJet = Ability.extend()

-- The legacy client waited half a second between two toggles.
NoseJet.Debounce = 0.5
NoseJet.Flight = true

function NoseJet:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function NoseJet:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local gain = BASE_GAIN + self:GetLevel("Defense") * GAIN_PER_LEVEL * self:GetAffinity("Defense")
	local speed = math.round(gain * GAIN_TO_SPEED)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function NoseJet:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return NoseJet
