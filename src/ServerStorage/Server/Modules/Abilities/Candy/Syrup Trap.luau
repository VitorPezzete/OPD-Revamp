--!strict
--[[
	Candy fruit - Syrup Trap: a pool of syrup spreads from under the caster.

	With k = defense affinity * (defense level / cap):
	- the pool stays where it was cast, 3 studs under the root; its diameter grows
	  linearly to 125 * k over 10 s, stays 5 s, then shrinks back to nothing over 10 s;
	- every 0.4 s everyone inside (flat distance <= current radius, within 8 studs
	  vertically) takes 25 * k, Special, not dodgeable (doubled, still Special, when
	  armament haki was on at the cast) and is stuck: CandyTouched for 3 s;
	- 26 s cooldown.
	- KeepThroughStun: a pool already cast keeps soaking when its caster is stunned, as in
	  the legacy game (it cannot be cast while stunned).

	Visual: Effects.OneShot.CandyTrap.

	Legacy problems fixed here:
	- Each pool carried a Script with a Heartbeat loop over every player and enemy that
	  spawned a coroutine per victim and was never disconnected; the pool was resized by
	  the server every frame. It is one bounded chain of delayed cylinder queries now.
	- The damage was written to values on the script template shared by every pool.
	- The pool was parented inside the caster's character and vanished with it; the
	  damage still stops on death (OnInterrupt), the picture finishes its animation.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CandyShared = require(script.Parent._Shared)

local EFFECT = "CandyTrap"

local DAMAGE = 25
local DIAMETER = 125
local GROW_TIME = 10
local HOLD_TIME = 5
local SHRINK_TIME = 10
local TICK_INTERVAL = 0.4
local TOUCH_HITS = 3
local GROUND_OFFSET = 3
local HALF_HEIGHT = 8

type Pool = {
	Start: number,
	Center: Vector3,
	Diameter: number,
	Damage: number,
}

local SyrupTrap = Ability.extend()

SyrupTrap.Debounce = 26
SyrupTrap.KeepThroughStun = true

-- One damage tick; reschedules itself until the pool is gone (63 rounds at most).
local function soak(self: any, pool: Pool, epoch: number)
	if (self.Epoch or 0) ~= epoch then
		return
	end

	local elapsed = os.clock() - pool.Start
	if elapsed >= GROW_TIME + HOLD_TIME + SHRINK_TIME then
		return
	end

	local alpha = 1
	if elapsed < GROW_TIME then
		alpha = elapsed / GROW_TIME
	elseif elapsed > GROW_TIME + HOLD_TIME then
		alpha = 1 - (elapsed - GROW_TIME - HOLD_TIME) / SHRINK_TIME
	end

	local radius = pool.Diameter * alpha / 2
	if radius > 0 then
		for _, target in Hitbox.Cylinder(pool.Center, radius, HALF_HEIGHT, self.Entity) do
			self:Damage(target, pool.Damage, "Special", EFFECT, false)
			CandyShared.Touch(self, target, TOUCH_HITS)
		end
	end

	task.delay(TICK_INTERVAL, soak, self, pool, epoch)
end

function SyrupTrap:CanBegin(): boolean
	return not CandyShared.Stunned(self)
end

function SyrupTrap:OnBegin()
	local entity = self.Entity
	local scale = self:GetAffinity("Defense") * self:GetLevelScale("Defense")
	local multiplier, haki = CandyShared.Haki(self)

	local pool: Pool = {
		Start = os.clock(),
		Center = entity.Root.Position - Vector3.new(0, GROUND_OFFSET, 0),
		Diameter = DIAMETER * scale,
		Damage = DAMAGE * scale * multiplier,
	}

	self:PlayEffect(EFFECT, pool.Center, {
		Diameter = pool.Diameter,
		GrowTime = GROW_TIME,
		HoldTime = HOLD_TIME,
		ShrinkTime = SHRINK_TIME,
		Haki = haki,
	})

	task.delay(TICK_INTERVAL, soak, self, pool, self.Epoch or 0)
end

function SyrupTrap:OnInterrupt()
	-- The pool stops hurting and slowing.
	self.Epoch = (self.Epoch or 0) + 1
end

return SyrupTrap
