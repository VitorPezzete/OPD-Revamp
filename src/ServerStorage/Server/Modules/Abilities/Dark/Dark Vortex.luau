--!strict
--[[
	Dark fruit - Dark Vortex: a vortex opens 25 studs above the user and swallows
	everyone around it.

	With m = melee affinity and s = melee level / cap:
	- everyone within 55 * m studs of the vortex when it opens is stunned for 1.5 * m s
	  and takes 200 * s * m, Special, not dodgeable, ten times (every 0.15 * m s);
	- they are dragged to the vortex for as long as its shell takes to collapse: the
	  shell is 100 * s * m studs wide and shrinks by 70 studs per second. The drag is the
	  legacy BodyPosition in the victim's root (MaxForce 1e8, P 10000, D 1000), on the
	  victim's client for a player and on the server for an NPC; when it ends they drop;
	- 8 s cooldown shared with Black Hole; Dark Star is blocked for 7 s, and the vortex
	  cannot be opened while Dark Star is being charged.

	KeepThroughStun: a vortex already open keeps swallowing when its caster is stunned, as
	in the legacy game (it cannot be opened while stunned). Death, a seal and losing the
	fruit close it.

	Legacy problems fixed here:
	- Victims were found by walking every descendant of the workspace, and each one got
	  a server BodyPosition and its own damage loop.
	- The BodyPositions were only removed by the Heartbeat callback that shrank the
	  shell, so a caster leaving mid-vortex left its victims hanging. The pull is a
	  timed status here and always ends.
	- The vortex, its shell and the shrinking ran on the server every Heartbeat.

	The legacy vortex animation was commented out and is not played.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local EFFECT = "DarkVortex"
local DAMAGE_TAG = "DarkVortex"
local STUN = "DarkVortex"

local COOLDOWN = 8
local RECENT_TIME = 7
local HEIGHT = 25
local RADIUS = 55
local DAMAGE = 200
local TICKS = 10
local TICK_INTERVAL = 0.15
local SHELL_SIZE = 100
local SHELL_SHRINK_RATE = 70
-- The shell counts as collapsed at this size.
local SHELL_MIN_SIZE = 0.1
local PULL_MOVER: Shared.Mover = { MaxForce = Vector3.new(1e8, 1e8, 1e8), P = 10000, D = 1000 }

type Cast = {
	Center: Vector3,
	Targets: { CharacterEntity },
	Damage: number,
	Interval: number,
}

local DarkVortex = Ability.extend()

DarkVortex.KeepThroughStun = true

-- One damage tick for every victim; reschedules itself until the ten are done.
local function pulse(self: any, cast: Cast, epoch: number, remaining: number)
	if (self.Epoch or 0) ~= epoch then
		return
	end

	for _, target in cast.Targets do
		if not target.Dead then
			self:Damage(target, cast.Damage, "Special", DAMAGE_TAG, false)
		end
	end

	if remaining > 1 then
		task.delay(cast.Interval, pulse, self, cast, epoch, remaining - 1)
	else
		self.Cast = nil
	end
end

function DarkVortex:CanBegin(): boolean
	return not self.Entity:HasStatus(Shared.CooldownStatus) and Shared.CanCast(self.Entity)
end

function DarkVortex:OnBegin()
	local entity = self.Entity
	local affinity = self:GetAffinity("Melee")
	local scale = affinity * self:GetLevelScale("Melee")

	entity:SetStatus(Shared.CooldownStatus, true, COOLDOWN)
	self:StartCooldown(COOLDOWN)
	Shared.MarkRecent(entity, RECENT_TIME)

	-- A previous vortex is always over by now (the cooldown is longer than its ticks).
	self:OnInterrupt()

	-- The vortex keeps the orientation the user had when it opened.
	local placement = entity.Root.CFrame * CFrame.new(0, HEIGHT, 0)
	local center = placement.Position
	local shellSize = SHELL_SIZE * scale
	local pullTime = math.max(shellSize - SHELL_MIN_SIZE, 0) / SHELL_SHRINK_RATE
	local interval = TICK_INTERVAL * affinity

	local cast: Cast = {
		Center = center,
		Targets = Hitbox.Sphere(center, RADIUS * affinity - Shared.BodyRadius, entity),
		Damage = DAMAGE * scale,
		Interval = interval,
	}
	self.Cast = cast

	self:PlayEffect(EFFECT, center, { CFrame = placement, Size = shellSize, ShrinkRate = SHELL_SHRINK_RATE })

	for _, target in cast.Targets do
		self.Services.Status:ApplyStun(target, interval * TICKS, STUN)
		if pullTime > 0 then
			Shared.Pull(target, center, pullTime, PULL_MOVER)
		end
	end

	pulse(self, cast, self.Epoch or 0, TICKS)
end

function DarkVortex:OnInterrupt()
	self.Epoch = (self.Epoch or 0) + 1

	-- Let go of whoever is still held.
	local cast: Cast? = self.Cast
	self.Cast = nil
	if cast then
		for _, target in cast.Targets do
			self.Services.Status:Clear(target, STUN)
			Shared.Release(target)
		end
	end
end

return DarkVortex
