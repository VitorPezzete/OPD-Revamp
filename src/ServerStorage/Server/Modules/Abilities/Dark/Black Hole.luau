--!strict
--[[
	Dark fruit - Black Hole: a pool of darkness spreads from under the user, drags in
	whoever stands on it and crushes them.

	With d = defense affinity and s = defense level / cap:
	- the pool stays where it was cast, 3 studs under the root; its diameter grows
	  linearly to 300 * s * d over 1.5 * d s, then shrinks by 60 studs per second;
	- everyone on it (root within the current radius, flat, and within 5 studs
	  vertically) takes 50 * s, Special, not dodgeable (no affinity in the damage, as in
	  the legacy game) the moment the pool reaches them and every 0.29 s after that, and
	  is stunned by each hit (0.4 s for players, 1.5 s for NPCs);
	- a player on it is snapped to the centre of the pool and held there until 0.5 s
	  after leaving it (the legacy script put a BodyPosition of MaxForce 1e5, P 5e4,
	  D 1e3 in the torso every frame, each living 0.5 s); an NPC is dragged flat towards
	  the centre, sinking half a stud at a time (one BodyPosition of MaxForce
	  1e6 / 7000 / 1e6, P 300, D 100, re-aimed every 0.1 s);
	- players are let go once the closing pool is under 2 studs wide;
	- 17 s cooldown shared with Dark Vortex; Dark Star is blocked for 17 s, and the pool
	  cannot be cast while Dark Star is being charged.

	KeepThroughStun: a pool already cast keeps crushing when its caster is stunned, as in
	the legacy game (it cannot be cast while stunned). Death, a seal and losing the fruit
	stop it.

	Legacy problems fixed here:
	- Each pool carried a Script with a Heartbeat loop over every player and enemy that
	  spawned a coroutine per victim and created a new BodyPosition (plus a cleaning
	  Script) inside the victim every frame. It is one bounded chain of delayed cylinder
	  queries now (ten a second); players are held by their own client
	  (Effects.Status.DarkPulled) with one mover as strong as that pile.
	- The damage was written to a value shared by every pool of the caster.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local EFFECT = "DarkBlackHole"
local DAMAGE_TAG = "DarkBlackHole"
local STUN = "DarkBlackHole"

local COOLDOWN = 17
local DAMAGE = 50
local DIAMETER = 300
local GROW_TIME = 1.5
local SHRINK_RATE = 60
-- Seconds between two hits on the same victim.
local HIT_INTERVAL = 0.29
-- How often the pool looks for who stands on it (the legacy NPC loop).
local STEP = 0.1
local GROUND_OFFSET = 3
local HALF_HEIGHT = 5
local PLAYER_STUN = 0.4
local NPC_STUN = 1.5
-- A closing pool narrower than this no longer holds players, if it ever was wider
-- than PLAYER_ARMED_DIAMETER.
local PLAYER_MIN_DIAMETER = 2
local PLAYER_ARMED_DIAMETER = 10

-- Players: the per-frame movers of the last 0.5 s added up (about 30 at 60 Hz).
local PLAYER_PULL_TIME = 0.5
local PLAYER_MOVER: Shared.Mover = { MaxForce = Vector3.new(3e6, 3e6, 3e6), P = 5e4, D = 1e3 }
-- NPCs: one mover, dropped as soon as the NPC is off the pool.
local NPC_PULL_TIME = 2 * STEP
local NPC_SINK = 0.5
local NPC_MOVER: Shared.Mover = { MaxForce = Vector3.new(1e6, 7000, 1e6), P = 300, D = 100 }

type Pool = {
	Start: number,
	Center: Vector3,
	Diameter: number,
	GrowTime: number,
	ShrinkTime: number,
	Damage: number,
	LastHit: { [any]: number },
}

local BlackHole = Ability.extend()

BlackHole.KeepThroughStun = true

-- One look at who stands on the pool; reschedules itself until the pool has closed.
local function crush(self: any, pool: Pool, epoch: number)
	if (self.Epoch or 0) ~= epoch then
		return
	end

	local now = os.clock()
	local elapsed = now - pool.Start
	if elapsed >= pool.GrowTime + pool.ShrinkTime then
		return
	end

	local growing = elapsed <= pool.GrowTime
	local alpha = if growing then elapsed / pool.GrowTime else 1 - (elapsed - pool.GrowTime) / pool.ShrinkTime
	local diameter = pool.Diameter * alpha
	local playersHeld = growing or pool.Diameter <= PLAYER_ARMED_DIAMETER or diameter >= PLAYER_MIN_DIAMETER

	local center = pool.Center
	local victims = Hitbox.Cylinder(center, diameter / 2 - Shared.BodyRadius, HALF_HEIGHT - Shared.BodyRadius, self.Entity)
	for _, target in victims do
		local isPlayer = target.Player ~= nil
		if isPlayer and not playersHeld then
			continue
		end

		if now - (pool.LastHit[target] or 0) >= HIT_INTERVAL then
			pool.LastHit[target] = now
			self:Damage(target, pool.Damage, "Special", DAMAGE_TAG, false)
			self.Services.Status:ApplyStun(target, if isPlayer then PLAYER_STUN else NPC_STUN, STUN)
		end

		if target.Dead then
			continue
		end
		if isPlayer then
			Shared.Pull(target, center, PLAYER_PULL_TIME, PLAYER_MOVER)
		else
			local point = Vector3.new(center.X, target.Root.Position.Y - NPC_SINK, center.Z)
			Shared.Pull(target, point, NPC_PULL_TIME, NPC_MOVER)
		end
	end

	task.delay(STEP, crush, self, pool, epoch)
end

function BlackHole:CanBegin(): boolean
	return not self.Entity:HasStatus(Shared.CooldownStatus) and Shared.CanCast(self.Entity)
end

function BlackHole:OnBegin()
	local entity = self.Entity
	local affinity = self:GetAffinity("Defense")
	local levelScale = self:GetLevelScale("Defense")
	local diameter = DIAMETER * levelScale * affinity
	if diameter <= 0 then
		return
	end

	entity:SetStatus(Shared.CooldownStatus, true, COOLDOWN)
	self:StartCooldown(COOLDOWN)
	Shared.MarkRecent(entity, COOLDOWN)

	local pool: Pool = {
		Start = os.clock(),
		Center = entity.Root.Position - Vector3.new(0, GROUND_OFFSET, 0),
		Diameter = diameter,
		GrowTime = GROW_TIME * affinity,
		ShrinkTime = diameter / SHRINK_RATE,
		Damage = DAMAGE * levelScale,
		LastHit = {},
	}

	self:PlayEffect(EFFECT, pool.Center, {
		Diameter = pool.Diameter,
		GrowTime = pool.GrowTime,
		ShrinkTime = pool.ShrinkTime,
	})

	self.Epoch = (self.Epoch or 0) + 1
	task.delay(STEP, crush, self, pool, self.Epoch)
end

function BlackHole:OnInterrupt()
	-- The pool stops crushing; stuns and pulls already given run out within 0.5 s (1.5 s of stun on NPCs).
	self.Epoch = (self.Epoch or 0) + 1
end

return BlackHole
