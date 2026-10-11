--!strict
--[[
	Dough fruit - Donut Roll: while the key is held the user turns into a rolling mochi
	donut that accelerates to 250 studs per second, climbs walls, rolls over the sea and
	can jump. No damage.

	The movement is the owner's (its client simulates its own character, as in the source):
	Effects.Status.DoughRoll has the physics, number for number. What the server decides is
	whether the roll is on, and the one number the source let the client send: the jump
	strength `5 * f`, f = Shared.Factor (melee). It is computed here and handed to the
	client in the status value.

	Status DoughRoll (replicated): "<f>|<fruit colors>".

	Gates, as the source client: not seated, no flight lock (its `FDP` counter), 1 s
	cooldown after the roll ends. The roll ends on release, when the user sits, dies or is
	sealed, and when any power raises the flight lock: it is a `Flight` for AbilityService,
	which also means its own key never raises the lock (the source's Power4 never called
	AbilityActivated). The source server did not look at NoMovement, so neither does the
	take-off.

	The source did not tie the roll to the fruit's `using` flag in any way that held (the
	client started it regardless), so it can be started while another Dough power charges.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local SKILL = "Melee"
local STATUS = "DoughRoll"
local COOLDOWN = 1

local DonutRoll = Ability.extend()

DonutRoll.Flight = true

function DonutRoll:CanBegin(): boolean
	return not self.Active
		and os.clock() >= (self.ReadyAt or 0)
		and not self.Entity.Humanoid.Sit
		and not self:IsFlightBlocked(true)
end

function DonutRoll:OnBegin()
	local entity = self.Entity
	self.Active = true
	entity:SetStatus(STATUS, `{Shared.Factor(self, SKILL)}|{self:GetColorString()}`, nil, true)

	self.SitConnection = entity.Humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		self:OnInterrupt()
	end)
end

function DonutRoll:OnEnd()
	self:OnInterrupt()
end

function DonutRoll:OnInterrupt()
	if not self.Active then
		return
	end
	self.Active = false
	if self.SitConnection then
		self.SitConnection:Disconnect()
		self.SitConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
end

return DonutRoll
