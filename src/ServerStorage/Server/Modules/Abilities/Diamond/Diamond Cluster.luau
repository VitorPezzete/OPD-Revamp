--!strict
--[[
	Diamond fruit - Diamond Cluster (charged): a cluster of diamond erupts around the
	caster, cutting everyone it engulfs, and stays as an obstacle.

	Hold to charge: 25 charge per second, from 4 up to 100 (4s for a full charge).
	With s = defense affinity * (defense level / cap) * charge / 100, on release:
	- Cluster size 45s x 35s x 45s, centred 2 studs below the caster's root.
	- Everyone inside takes 800 * s "Sword" damage, once. Armament haki doubles it and
	  makes it "Haki". The cluster cuts for its first 0.5 s (the legacy part listened to
	  touches for that long), so whoever runs into it right after it erupts is hit too.
	- The cluster stands for 10s, then shrinks away over 5s (client side).
	- 0.5s between presses and 1s after a release before the next charge.

	Legacy problems fixed here:
	- A "StopCharging" without a charge running still produced a minimum-charge cluster
	  (the stored start time was reset to a huge number, clamped up to 4).
	- Charge state was one table per script keyed by power name, with client-reported
	  charge sent alongside; the hold is timed here by BeginCharge / EndCharge.
	- Hits came from a 0.5s Touched connection on a part tweened from 0.1 studs, which
	  missed targets standing still. It is a box query of the final size, repeated over
	  those 0.5 s.
	- The cluster was a server part parented inside the character; it is a client effect.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

local EFFECT = "DiamondCluster"
-- Replicated while charging: drives the owner's charge animation and facing.
local CHARGE_STATUS = "DiamondCharging"
local HAKI_STATUS = "Haki"

local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 100
local RECAST_DELAY = 1

local DAMAGE = 800
local HAKI_MULTIPLIER = 2
local SIZE = Vector3.new(45, 35, 45)
local OFFSET = CFrame.new(0, -2, 0)
local STAND_TIME = 10
local SHRINK_TIME = 5
-- The cluster cuts whoever touches it for this long, looked up this often.
local CUT_TIME = 0.5
local CUT_STEP = 0.125

local DiamondCluster = Ability.extend()

DiamondCluster.Debounce = 0.5

function DiamondCluster:CanBegin(): boolean
	return os.clock() - (self.LastRelease or 0) >= RECAST_DELAY
end

function DiamondCluster:OnBegin()
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)
	self.Entity:SetStatus(CHARGE_STATUS, true, nil, true)
end

function DiamondCluster:OnEnd()
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	self.Entity:ClearStatus(CHARGE_STATUS)
	if not charge then
		return
	end
	self.LastRelease = os.clock()
	self:StartCooldown(RECAST_DELAY)

	local scale = self:GetAffinity("Defense") * self:GetLevelScale("Defense") * charge / 100
	local size = SIZE * scale
	local cframe = self.Entity.Root.CFrame * OFFSET

	local haki = self.Entity:HasStatus(HAKI_STATUS)
	local damage = DAMAGE * scale * (if haki then HAKI_MULTIPLIER else 1)
	local entity = self.Entity
	local trait = if haki then "Haki" else "Sword"
	local cut: { [any]: boolean } = {}
	local function sweep(elapsed: number)
		if entity.Dead then
			return
		end
		for _, target in Hitbox.Box(cframe, size, entity) do
			if not cut[target] then
				cut[target] = true
				self:Damage(target, damage, trait, EFFECT, false)
			end
		end
		if elapsed + CUT_STEP <= CUT_TIME then
			task.delay(CUT_STEP, sweep, elapsed + CUT_STEP)
		end
	end
	sweep(0)

	self:PlayEffect(EFFECT, cframe.Position, {
		CFrame = cframe,
		Size = size,
		StandTime = STAND_TIME,
		ShrinkTime = SHRINK_TIME,
		Haki = haki,
	})
end

function DiamondCluster:OnInterrupt()
	self.ChargeStart = nil
	self.Entity:ClearStatus(CHARGE_STATUS)
end

return DiamondCluster
