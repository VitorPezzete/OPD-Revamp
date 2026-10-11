--!strict
--[[
	Love fruit - Arrow Storm (charged): arrows shot at the sky that rain back down
	around the user.

	With s = sniper affinity * (sniper level / cap):
	- Charge: 25 per second held, 4 to 100 (measured on the server).
	- Arrows: floor((sniper level - 50) / 50) + 1 volleys start 0.1 s apart; each volley
	  is floor(clamp(5 * affinity * charge / 100, 2, 10)) arrows 0.15 s apart, and every
	  arrow whose turn comes after the last volley started is dropped (see
	  _Shared.Volley): about 40 arrows at level 500 with a full charge.
	- Arrow: leaves the chest straight up, tilted by -5 to +2.5 degrees on each axis (the
	  legacy spread was lopsided), at clamp(500 * charge / 100, 200, 500) studs per
	  second, and falls back with gravity. Its heart grows to 17.5 * affinity studs
	  over 3 s.
	- Everyone the heart passes over, on the way up or down, is petrified for
	  5 * charge / 100 * s seconds.
	- The heart held above the shoulder and the charge pose stay until the last volley
	  has started (LoveCharging status).
	- 3 s cooldown after the last volley started, which also closes Slave Arrow; Arrow
	  Storm itself waits for the cooldowns of Beam and Slave Arrow (see _Shared).

	Legacy problems are listed in _Shared (arrows) and Beam (request flooding).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Love = require(script.Parent._Shared)

local KIND = "Storm"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local ARROWS = 5
local MIN_ARROWS = 2
local MAX_ARROWS = 10
local SPEED = 500
local MIN_SPEED = 200
local SPREAD_MIN_DEGREES = -5
local SPREAD_MAX_DEGREES = 2.5
local STUN_TIME = 5
local GROW_TIME = 3
local VOLLEY_INTERVAL = 0.1
local ARROW_INTERVAL = 0.15
local COOLDOWN = 3
-- Cooldowns that keep Arrow Storm shut, and the abilities its own cooldown closes.
local OBEYS = { "Arrow Storm", "Beam", "Slave Arrow" }
local CLOSES = { "Slave Arrow" }

local ArrowStorm = Ability.extend()

function ArrowStorm:CanBegin(): boolean
	local entity = self.Entity
	return not self.ChargeStart and not self.Active and not Love.IsBusy(entity) and not Love.IsLocked(entity, OBEYS)
end

function ArrowStorm:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	self.Entity:SetStatus(Love.CHARGE_STATUS, `{KIND}|{self:GetColorString()}|{scale}`, nil, true)
end

function ArrowStorm:OnEnd()
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity
	local affinity: number = self:GetAffinity("Sniper")
	local volleys = math.max(1, math.floor((self:GetLevel("Sniper") - 50) / 50) + 1)

	self.Active = true
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
			return entity.Root.Position, Love.Spread(Vector3.yAxis, SPREAD_MIN_DEGREES, SPREAD_MAX_DEGREES)
		end,
		IsLive = function(): boolean
			return self.Run == run
		end,
	})

	Love.Lock(self, window + COOLDOWN, CLOSES)

	task.delay(window, function()
		if self.Run == run then
			self.Active = false
			entity:ClearStatus(Love.CHARGE_STATUS)
			Love.PlayRelease(self, KIND)
		end
	end)
end

function ArrowStorm:OnInterrupt()
	self.ChargeStart = nil
	self.Active = false
	-- Arrows that have not left yet are dropped.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(Love.CHARGE_STATUS)
end

return ArrowStorm
