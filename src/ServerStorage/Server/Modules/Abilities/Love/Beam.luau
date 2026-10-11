--!strict
--[[
	Love fruit - Beam (charged): a salvo of hearts that petrify whoever they pass through.

	With s = sniper affinity * (sniper level / cap):
	- Charge: 25 per second held, 4 to 100 (measured on the server).
	- On release floor((sniper level - 50) / 50) + 1 hearts leave 0.2 s apart (4 at level
	  200, 10 at level 500). Each one leaves towards where the caster is aiming at that
	  moment: the owner's client keeps sending its aim during the salvo (LoveSalvo
	  status, phase 3 inputs), as the legacy client sent the mouse with every heart.
	- Heart: 20 * charge / 100 * (level / cap) studs wide, 100 * affinity studs per
	  second, alive for 5 s. It pierces characters and petrifies each of them once for
	  15 * charge / 100 * s seconds (see _Shared). No damage.
	- The heart held in front of the chest and the aiming pose stay until the last heart
	  has left (LoveCharging status).
	- 3 s cooldown after the salvo, which also closes Glare, Slave Arrow and Arrow Storm;
	  Beam itself waits for Slave Arrow's cooldown (see _Shared).

	Legacy problems fixed here:
	- The number of hearts was a client loop of "StopCharging" requests, the charge of
	  the salvo lived in one script-level variable and the server accepted any number of
	  requests: a modified client could fire hearts without limit.
	- The heart was an unanchored server part pushed by a BodyVelocity with two Touched
	  connections. It is a server-simulated Projectile now and stops at the first wall.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local Love = require(script.Parent._Shared)

local EFFECT = "LoveBeam"
local KIND = "Beam"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local HEART_SIZE = 20
local HEART_SPEED = 100
local HEART_LIFETIME = 5
local STUN_TIME = 15
local SHOT_INTERVAL = 0.2
local COOLDOWN = 3
-- Cooldowns that keep Beam shut, and the abilities Beam's own cooldown closes.
local OBEYS = { "Beam", "Slave Arrow" }
local CLOSES = { "Glare", "Slave Arrow", "Arrow Storm" }

local Beam = Ability.extend()

function Beam:CanBegin(): boolean
	local entity = self.Entity
	return not self.ChargeStart and not self.Active and not Love.IsBusy(entity) and not Love.IsLocked(entity, OBEYS)
end

function Beam:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	-- "<kind>|<colors>|<scale>": the heart growing in front of the chest.
	local scale = self:GetAffinity("Sniper") * self:GetLevelScale("Sniper")
	self.Entity:SetStatus(Love.CHARGE_STATUS, `{KIND}|{self:GetColorString()}|{scale}`, nil, true)
end

function Beam:OnEnd(input)
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge then
		return
	end

	local entity = self.Entity
	local context = self.Context
	local affinity: number = self:GetAffinity("Sniper")
	local levelScale: number = self:GetLevelScale("Sniper")
	local diameter = HEART_SIZE * charge / 100 * levelScale
	local speed = HEART_SPEED * affinity
	local stunTime = STUN_TIME * charge / 100 * affinity * levelScale
	local shots = math.max(1, math.floor((self:GetLevel("Sniper") - 50) / 50) + 1)
	local window = shots * SHOT_INTERVAL

	self.Active = true
	self.Aim = input.AimPosition
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	Love.Lock(self, window + COOLDOWN, CLOSES)
	-- "<fruit slot>|<ability slot>": where the owner's client sends its aim.
	entity:SetStatus(Love.SALVO_STATUS, `{context.FruitSlot}|{context.Definition.Slot}`, nil, true)

	local function fire()
		if self.Run ~= run or entity.Dead then
			return
		end

		local origin = entity.Root.Position
		local direction = self.Aim - origin
		direction = if direction.Magnitude > 0.05 then direction.Unit else entity.Root.CFrame.LookVector
		local range = speed * HEART_LIFETIME
		direction = Projectile.Lead(entity, origin, direction, speed, range)

		Projectile.Fire({
			Origin = origin,
			Direction = direction,
			Speed = speed,
			MaxDistance = range,
			Radius = diameter / 2,
			Owner = entity,
			Pierce = true,
			-- The legacy heart appeared on the chest and touched whoever stood in it.
			HitOverlapping = true,
			-- A heart that has left keeps petrifying whatever happens to its caster,
			-- short of dying.
			OnHit = function(target)
				if not entity.Dead then
					Love.Stun(self, target, stunTime)
				end
			end,
		})
		self:PlayEffect(EFFECT, origin, {
			Direction = direction,
			Speed = speed,
			Range = range,
			Size = diameter,
		})
	end

	for shot = 0, shots - 1 do
		task.delay(shot * SHOT_INTERVAL, fire)
	end
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
function Beam:OnAction(input)
	self.Aim = input.AimPosition
end

function Beam:OnInterrupt()
	self.ChargeStart = nil
	self.Active = false
	-- Hearts that have not left yet are dropped.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(Love.CHARGE_STATUS)
	self.Entity:ClearStatus(Love.SALVO_STATUS)
end

return Beam
