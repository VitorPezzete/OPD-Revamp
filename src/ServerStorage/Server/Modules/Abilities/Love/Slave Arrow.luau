--!strict
--[[
	Love fruit - Slave Arrow (charged): heart-tipped arrows shot at the mouse.

	With s = sniper affinity * (sniper level / cap):
	- Charge: 25 per second held, 4 to 100 (measured on the server).
	- Arrows: floor((sniper level - 50) / 50) + 1 volleys start 0.1 s apart; each volley
	  is floor(clamp(3 * affinity * charge / 100, 1, 6)) arrows 0.25 s apart, and every
	  arrow whose turn comes after the last volley started is dropped (see
	  _Shared.Volley for why): 8 arrows at level 250, 26 at level 500 with a full charge.
	- Arrow: leaves 3 studs in front of the chest towards where the caster is aiming at
	  that moment (the owner's client keeps sending its aim during the salvo, LoveSalvo
	  status), within a 5 degree spread, at clamp(750 * charge / 100, 200, 750) studs per
	  second, and falls with gravity. Its heart grows to 17.5 * affinity studs over 1 s.
	- Everyone the heart passes over is petrified for 5 * charge / 100 * s seconds.
	- The heart held in front of the chest and the aiming pose stay until the last
	  volley has started (LoveCharging status).
	- 3 s cooldown after the last volley started, which also closes Glare, Beam and
	  Arrow Storm; Slave Arrow itself waits for the cooldowns of both (see _Shared).

	Legacy problems are listed in _Shared (arrows) and Beam (request flooding).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Love = require(script.Parent._Shared)

local KIND = "Arrow"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local ARROWS = 3
local MIN_ARROWS = 1
local MAX_ARROWS = 6
local SPEED = 750
local MIN_SPEED = 200
local SPREAD_DEGREES = 5
local STUN_TIME = 5
local GROW_TIME = 1
local VOLLEY_INTERVAL = 0.1
local ARROW_INTERVAL = 0.25
local MUZZLE_OFFSET = CFrame.new(0, 0, -3)
local COOLDOWN = 3
-- Cooldowns that keep Slave Arrow shut, and the abilities its own cooldown closes.
local OBEYS = { "Slave Arrow", "Beam", "Arrow Storm" }
local CLOSES = { "Glare", "Beam", "Arrow Storm" }

local SlaveArrow = Ability.extend()

function SlaveArrow:CanBegin(): boolean
	local entity = self.Entity
	return not self.ChargeStart and not self.Active and not Love.IsBusy(entity) and not Love.IsLocked(entity, OBEYS)
end

function SlaveArrow:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	self.Entity:SetStatus(Love.CHARGE_STATUS, `{KIND}|{self:GetColorString()}|{scale}`, nil, true)
end

function SlaveArrow:OnEnd(input)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity
	local context = self.Context
	local affinity: number = self:GetAffinity("Sniper")
	local volleys = math.max(1, math.floor((self:GetLevel("Sniper") - 50) / 50) + 1)

	self.Active = true
	self.Aim = input.AimPosition
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local window = Love.Volley(self, volleys, {
		VolleyInterval = VOLLEY_INTERVAL,
		ArrowInterval = ARROW_INTERVAL,
		ArrowsPerVolley = math.floor(math.clamp(ARROWS * affinity * charge / 100, MIN_ARROWS, MAX_ARROWS)),
		Speed = math.clamp(SPEED * charge / 100, MIN_SPEED, SPEED),
		StunTime = STUN_TIME * charge / 100 * affinity * self:GetLevelScale("Sniper"),
		GrowTime = GROW_TIME,
		Launch = function(): (Vector3, Vector3)
			local origin = (entity.Root.CFrame * MUZZLE_OFFSET).Position
			local direction = self.Aim - origin
			if direction.Magnitude < 0.05 then
				direction = entity.Root.CFrame.LookVector
			end
			return origin, Love.Spread(direction, -SPREAD_DEGREES, SPREAD_DEGREES)
		end,
		IsLive = function(): boolean
			return self.Run == run
		end,
	})

	Love.Lock(self, window + COOLDOWN, CLOSES)
	-- "<fruit slot>|<ability slot>": where the owner's client sends its aim.
	entity:SetStatus(Love.SALVO_STATUS, `{context.FruitSlot}|{context.Definition.Slot}`, nil, true)

	task.delay(window, function()
		if self.Run == run then
			self.Active = false
			entity:ClearStatus(Love.SALVO_STATUS)
			entity:ClearStatus(Love.CHARGE_STATUS)
			Love.PlayRelease(self, KIND)
		end
	end)
end

-- The aim of the salvo in flight, streamed by the owner's client.
function SlaveArrow:OnAction(input)
	self.Aim = input.AimPosition
end

function SlaveArrow:OnInterrupt()
	self.ChargeStart = nil
	self.Active = false
	-- Arrows that have not left yet are dropped.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(Love.CHARGE_STATUS)
	self.Entity:ClearStatus(Love.SALVO_STATUS)
end

return SlaveArrow
