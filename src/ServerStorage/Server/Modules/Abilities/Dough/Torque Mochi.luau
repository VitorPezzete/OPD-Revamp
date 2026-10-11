--!strict
--[[
	Dough fruit - Torque Mochi (held, up to 10 s): the user grows a long mochi arm ending
	in a spiked haki ball and spins it around; whoever it sweeps is stuck to the ball and
	carried around, then thrown up and damaged when the spin ends.

	(The source's UI called it "[Disabled] Torque Mochi", but its code is complete.)

	With L = defense level / 500, a = defense affinity, t = seconds since the press:
	- the user stands still for the whole move (walk speed 0, jump power 0, no auto-rotate,
	  the legacy NoMovement flag) and its flights are grounded;
	- from t = 1 s, every 0.5 s: characters within 100 * (t / 10) * L * a + 30 studs of the
	  user (no "/ 2" in this one) and with a body part within 15 studs of its height are
	  caught, unless they are spinning a Torque Mochi themselves or their root is anchored.
	  Caught: sealed, rooted, immune to the sea (DamageModifiers.DoughTorqueWater), status
	  DoughTorqueCaught;
	- the spin ends on release or by itself at t = 10 s. 1.1 s later, with
	  f = L / 2 * a / 10 * t: every caught character is let go, stood upright, pushed up
	  at 150 * f studs per second for 0.25 s (BodyVelocity, MaxForce (0, inf, 0), P 100000)
	  and takes 15000 * f Special damage, not dodgeable. The user itself is moved
	  150 * c studs up and pushed up at 250 * c studs per second for 0.25 s,
	  c = clamp(t + 1.1, 0.1, 10) / 10: the source client did this to its own character
	  and read its clock AFTER the 1.1 s wait;
	- cooldown: 10 s after that, 11.1 s from the release.
	The spin outlives a stun or a seal of its user, as in the source; death ends it and
	frees everyone unharmed.

	WHO MOVES THE VICTIMS. The source gave the network ownership of every victim's root to
	the attacker, whose client then wrote their CFrame every frame: an exploit handed out
	by the server. Nobody's ownership changes here:
	- a caught PLAYER is pinned by its own client (Effects.Status.DoughTorqueCaught, the
	  `isLocal` branch) to the ball of the attacker's arm as that client draws it - the
	  very thing the source showed. The server does not depend on it: the catch, the seal,
	  the damage and the launch are decided here from the caught list, whatever the
	  victim's client does with its position.
	- a caught NPC is simulated by the server, which cannot see the arm (it follows a
	  client-side animation): it is carried on a circle around the user, at the arm's
	  current length, turning at the speed of the source's swing effect (half a turn every
	  0.415 s). One Heartbeat connection, only while an NPC is caught.

	Statuses on the user (replicated): DoughTorqueMochi = fruit colors for the whole move;
	DoughTorqueRelease = seconds charged, for its last 1.1 s (Effects.Status.DoughTorqueMochi
	draws both phases).

	The source required a `NetworkOwner` value in the victim, which the dump does not show
	on anything: every tracked character can be caught here.
]]
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local NAME = "Torque Mochi"
local SKILL = "Defense"
local ROOT = "DoughTorque"
local CAUGHT_ROOT = "DoughTorqueCaught"
local SEAL_SOURCE = "DoughTorque"
local DAMAGE_TAG = "DoughTorqueMochi"

local COOLDOWN = 10
local MAX_CHARGE = 10
local MAX_DAMAGE = 15000
local FIRST_CHECK = 0.5
local CHECK_INTERVAL = 0.5
local CATCH_RADIUS = 100
local CATCH_BASE = 30
-- Root heights, relative to the user's root, at which a body part is within 15 studs of it.
local CATCH_MIN_HEIGHT = -16.5
local CATCH_MAX_HEIGHT = 17
local END_DELAY = 1.1
local VICTIM_LIFT = 150
local VICTIM_LIFT_FORCE = Vector3.new(0, math.huge, 0)
local VICTIM_LIFT_POWER = 100000
local USER_RISE = 150
local USER_LIFT = 250
local LIFT_TIME = 0.25
local MIN_USER_CHARGE = 0.1

-- The arm as the clients draw it: 2 -> 30 studs in 0.2 s, the ball grows for 0.2 s, then
-- 30 -> 150 studs over 9.5 s; it shrinks to 5 studs over the last 0.25 s of the move.
local ARM_START = 2
local ARM_SHORT = 30
local ARM_LONG = 150
local ARM_GROW_TIME = 0.2
local ARM_HOLD_TIME = 0.4
local ARM_STRETCH_TIME = 9.5
local ARM_END = 5
local ARM_SHRINK_AT = 0.85
local ARM_SHRINK_TIME = 0.25
-- From the user's root to the start of the arm, plus the ball's radius.
local ARM_REACH = 2.5
-- Radians per second of the swing (the source's effect: pi every 0.415 s, clockwise).
local SPIN_SPEED = math.pi / 0.415

local TorqueMochi = Ability.extend()

-- The source dealt this damage without a style: ResistAbilities does not apply.
TorqueMochi.DamageStyle = "Plain"
TorqueMochi.KeepThroughStun = true
TorqueMochi.KeepThroughSeal = true

local function armLength(elapsed: number): number
	if elapsed < ARM_GROW_TIME then
		local alpha = elapsed / ARM_GROW_TIME
		return ARM_START + (ARM_SHORT - ARM_START) * (1 - (1 - alpha) * (1 - alpha))
	elseif elapsed < ARM_HOLD_TIME then
		return ARM_SHORT
	end
	return ARM_SHORT + (ARM_LONG - ARM_SHORT) * math.min((elapsed - ARM_HOLD_TIME) / ARM_STRETCH_TIME, 1)
end

function TorqueMochi:CanBegin(): boolean
	return not self.Active and os.clock() >= (self.ReadyAt or 0) and not Shared.IsUsing(self.Entity)
end

-- Where the ball is, for the server (see the header): only used to carry NPCs.
function TorqueMochi:BallPosition(): Vector3
	local now = os.clock()
	local began: number = self.Began
	local releasedAt: number? = self.ReleasedAt
	local length = armLength((releasedAt or now) - began)
	if releasedAt and now - releasedAt > ARM_SHRINK_AT then
		local alpha = math.min((now - releasedAt - ARM_SHRINK_AT) / ARM_SHRINK_TIME, 1)
		length += (ARM_END - length) * alpha
	end

	local root = self.Entity.Root
	local facing: CFrame = self.Facing
	local direction = (facing * CFrame.Angles(0, -SPIN_SPEED * (now - began), 0)).LookVector
	return root.Position + direction * (length + ARM_REACH)
end

function TorqueMochi:Carry()
	if self.CarryConnection then
		return
	end
	self.CarryConnection = RunService.Heartbeat:Connect(function()
		local position: Vector3 = self:BallPosition()
		local carried = false
		for target in self.Caught :: { [CharacterEntity]: boolean } do
			if not target.Player and not target.Dead and target.Root.Parent then
				carried = true
				target.Model:PivotTo(CFrame.new(position))
				target.Root.AssemblyLinearVelocity = Vector3.zero
			end
		end
		if not carried then
			self:StopCarrying()
		end
	end)
end

function TorqueMochi:StopCarrying()
	if self.CarryConnection then
		self.CarryConnection:Disconnect()
		self.CarryConnection = nil
	end
end

function TorqueMochi:Catch(target: CharacterEntity)
	self.Caught[target] = true
	target:SetRooted(CAUGHT_ROOT, true)
	target:SetStatus(Shared.CaughtStatus, self.Player.UserId, nil, true)
	self.Services.Ability:SetSealed(target, true, nil, SEAL_SOURCE)
	if not target.Player then
		self:Carry()
	end
end

-- Lets a victim go: no damage, no launch.
function TorqueMochi:Free(target: CharacterEntity)
	self.Caught[target] = nil
	target:SetRooted(CAUGHT_ROOT, false)
	target:ClearStatus(Shared.CaughtStatus)
	self.Services.Ability:SetSealed(target, false, nil, SEAL_SOURCE)
end

function TorqueMochi:OnBegin()
	local entity = self.Entity
	local humanoid = entity.Humanoid

	self.Active = true
	self.Releasing = false
	self.ReleasedAt = nil
	self.Began = os.clock()
	self.Facing = entity.Root.CFrame.Rotation
	self.Caught = {}
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	Shared.SetUsing(entity, NAME)
	self:BeginCharge(MAX_CHARGE)
	-- The source held the flight counter up for the whole move.
	self.Services.Ability:RaiseFlightLock(entity, MAX_CHARGE + END_DELAY + 1)

	entity:SetRooted(ROOT, true)
	self.JumpChange = -humanoid.JumpPower
	humanoid.JumpPower += self.JumpChange
	self.AutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	entity:SetStatus(Shared.TorqueStatus, self:GetColorString(), nil, true)

	local reach = self:GetLevelScale(SKILL) * self:GetAffinity(SKILL)

	local function check()
		if self.Run ~= run or self.Releasing or entity.Dead then
			return
		end
		local origin = entity.Root.Position
		local elapsed = os.clock() - self.Began
		-- Any refused press of another power restarts the lock at its default 3 s, which
		-- would let a flight (Donut Roll) take off mid-spin: keep it up for the whole move.
		self.Services.Ability:RaiseFlightLock(entity, math.max(MAX_CHARGE + END_DELAY + 1 - elapsed, END_DELAY))
		local radius = CATCH_RADIUS * (elapsed / MAX_CHARGE) * reach + CATCH_BASE
		for _, target in Hitbox.Sphere(origin, radius, entity) do
			local height = target.Root.Position.Y - origin.Y
			if
				not self.Caught[target]
				and not target.Root.Anchored
				and height > CATCH_MIN_HEIGHT
				and height < CATCH_MAX_HEIGHT
				and not target:HasStatus(Shared.TorqueStatus)
				-- Not in the source: two spinners would have fought over the same victim.
				and not target:HasStatus(Shared.CaughtStatus)
			then
				self:Catch(target)
			end
		end
		task.delay(CHECK_INTERVAL, check)
	end
	task.delay(FIRST_CHECK + CHECK_INTERVAL, check)

	-- The source client ended the move by itself when the charge was full.
	task.delay(MAX_CHARGE, function()
		if self.Run == run then
			self:Release()
		end
	end)
end

function TorqueMochi:Release()
	if not self.Active or self.Releasing then
		return
	end
	local entity = self.Entity
	local run = self.Run
	self.Releasing = true
	self.ReleasedAt = os.clock()
	self:EndCharge(1, 0, MAX_CHARGE)

	local charge = math.min(self.ReleasedAt - self.Began, MAX_CHARGE)
	local factor = Shared.Factor(self, SKILL) / MAX_CHARGE * charge
	-- The source client measured its own charge after waiting out the 1.1 s.
	local userFactor = math.clamp(charge + END_DELAY, MIN_USER_CHARGE, MAX_CHARGE) / MAX_CHARGE

	self.ReadyAt = self.ReleasedAt + END_DELAY + COOLDOWN
	self:StartCooldown(END_DELAY + COOLDOWN)
	self.Services.Ability:RaiseFlightLock(entity, END_DELAY)
	entity:SetStatus(Shared.TorqueReleaseStatus, charge, nil, true)

	task.delay(END_DELAY, function()
		if self.Run ~= run then
			return
		end

		local caught: { CharacterEntity } = {}
		for target in self.Caught do
			table.insert(caught, target)
		end
		self:Finish()

		for _, target in caught do
			if target.Dead or not target.Root.Parent then
				continue
			end
			-- A player's own client stands its character up when the status goes.
			if not target.Player then
				target.Model:PivotTo(CFrame.new(target.Root.Position))
			end
			self:Impulse(target, Vector3.new(0, VICTIM_LIFT * factor, 0), LIFT_TIME, VICTIM_LIFT_FORCE, VICTIM_LIFT_POWER)
			self:Damage(target, MAX_DAMAGE * factor, "Special", DAMAGE_TAG, false)
		end

		if not entity.Dead then
			self.Services.Character:Teleport(entity, entity.Root.CFrame * CFrame.new(0, USER_RISE * userFactor, 0))
			self:Impulse(entity, Vector3.new(0, USER_LIFT * userFactor, 0), LIFT_TIME, VICTIM_LIFT_FORCE)
		end
	end)
end

function TorqueMochi:OnEnd()
	self:Release()
end

-- Returns the user and every victim to neutral. Nobody is hurt here.
function TorqueMochi:Finish()
	if not self.Active then
		return
	end
	local entity = self.Entity
	local humanoid = entity.Humanoid

	self.Active = false
	self.Releasing = false
	self.Run = (self.Run or 0) + 1
	self:StopCarrying()

	local caught: { CharacterEntity } = {}
	for target in self.Caught do
		table.insert(caught, target)
	end
	for _, target in caught do
		self:Free(target)
	end

	entity:SetRooted(ROOT, false)
	if humanoid.Parent then
		humanoid.JumpPower -= self.JumpChange or 0
		humanoid.AutoRotate = self.AutoRotate ~= false
	end
	self.JumpChange = 0
	entity:ClearStatus(Shared.TorqueStatus)
	entity:ClearStatus(Shared.TorqueReleaseStatus)
	Shared.ClearUsing(entity, NAME)
end

function TorqueMochi:OnInterrupt()
	if not self.Active then
		return
	end
	-- Cut short (death, fruit lost): the cooldown still runs.
	if not self.Releasing then
		self.ReadyAt = os.clock() + COOLDOWN
		self:StartCooldown(COOLDOWN)
	end
	self:Finish()
end

return TorqueMochi
