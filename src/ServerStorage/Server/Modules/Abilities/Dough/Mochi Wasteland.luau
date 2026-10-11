--!strict
--[[
	Dough fruit - Mochi Wasteland: a pool of mochi spreads from under the user for 10 s and
	shrinks back for 20 s. Whoever stands in it is covered in mochi.

	With f = Shared.Factor (defense), read at the press, and the centre 3 studs below the
	user's root at that moment:
	- radius: 250 * f * (t / 10) for the first 10 s, then 250 * f * (1 - (t - 10) / 20)
	  until t = 30 s; checked every 0.25 s.
	- who: characters with a body part inside that sphere AND within 2.5 studs of the
	  pool's height (the source tested every part's centre: for a standing body that is a
	  root between 4 studs below and 4.5 studs above the centre).
	- covered (status DoughMochiCovered, replicated): walk speed x 0.1, jump power 8, the
	  legacy NoMovement flag (no Dash / Shave / take-off - see the report: the status has
	  to be listed in MovementConfig), and 50 * f Special damage every 0.5 s from the user,
	  the amount fixed when the cover started. The cover is lifted once the character has
	  been out of the pool for more than 1 s (found by the next 0.25 s check), and for
	  everyone when the pool is gone.
	- cooldown: 10 s after the 30 s, 40 s from the press.

	The pool outlives a stun or a seal of its user, as in the source (a running loop of
	the server script); it ends with the user's death, which the source did not handle
	(victims stayed covered for ever).

	NPCs are covered too (AFFECTS_NPCS), by decision of the owner. The source only covered
	characters that had a `MochiCovered` value, which is cloned into player characters
	(Workspace.AA.ToPlayerCharacter); nothing in the dump gives one to an enemy.

	The DoT is a StatusService row (0.5 s interval), which also owns the replicated status.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local SKILL = "Defense"
local EFFECT = "DoughWasteland"

local AFFECTS_NPCS = true

local COOLDOWN = 10
local DURATION = 30
local GROW_TIME = 10
local SHRINK_TIME = 20
local MAX_RADIUS = 250
local STEP = 0.25
local LINGER = 1
local MAX_DAMAGE = 50
local DOT_INTERVAL = 0.5
local SPEED_SCALE = 0.1
local JUMP_POWER = 8
local CENTER_OFFSET = Vector3.new(0, -3, 0)
-- Root heights, relative to the centre, at which a body part is within 2.5 studs of it.
local MIN_HEIGHT = -4
local MAX_HEIGHT = 4.5
-- Everyone who may see the pool at its widest.
local EFFECT_PADDING = 400

local MochiWasteland = Ability.extend()

MochiWasteland.KeepThroughStun = true
MochiWasteland.KeepThroughSeal = true

function MochiWasteland:CanBegin(): boolean
	return os.clock() >= (self.ReadyAt or 0) and not Shared.IsUsing(self.Entity)
end

function MochiWasteland:Cover(target: CharacterEntity, damage: number)
	local covered: { [CharacterEntity]: { LastSeen: number, Jump: number } } = self.Covered
	local entry = covered[target]
	if entry then
		entry.LastSeen = os.clock()
		return
	end
	-- Already in somebody else's pool: that one keeps the cover (the source's
	-- `if not MochiCovered.Value`).
	if target:HasStatus(Shared.CoveredStatus) then
		return
	end

	local jump = JUMP_POWER - target.Humanoid.JumpPower
	target.Humanoid.JumpPower += jump
	covered[target] = { LastSeen = os.clock(), Jump = jump }
	target:SetSpeedScale(Shared.CoveredStatus, SPEED_SCALE)
	self.Services.Status:ApplyDot(target, Shared.CoveredStatus, {
		Source = self.Entity,
		Damage = damage,
		Interval = DOT_INTERVAL,
		Ticks = math.ceil((DURATION + LINGER) / DOT_INTERVAL) + 1,
		Trait = "Special",
		-- The source dealt it without a style: ResistAbilities does not apply.
		Style = "Plain",
	})
end

function MochiWasteland:Uncover(target: CharacterEntity)
	local covered: { [CharacterEntity]: { LastSeen: number, Jump: number } } = self.Covered
	local entry = covered[target]
	if not entry then
		return
	end
	covered[target] = nil
	self.Services.Status:Clear(target, Shared.CoveredStatus)
	target:ClearStatus(Shared.CoveredStatus)
	target:SetSpeedScale(Shared.CoveredStatus, nil)
	if target.Humanoid.Parent then
		target.Humanoid.JumpPower -= entry.Jump
	end
end

function MochiWasteland:OnBegin()
	local entity = self.Entity
	local factor = Shared.Factor(self, SKILL)
	local origin = entity.Root.Position + CENTER_OFFSET
	local damage = MAX_DAMAGE * factor

	-- A pool still running (it cannot be: the cooldown is longer) would be replaced.
	self:Stop()
	self.Covered = {}
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	local began = os.clock()

	self.ReadyAt = began + DURATION + COOLDOWN
	self:StartCooldown(DURATION + COOLDOWN)
	self:PlayEffect(EFFECT, origin, { Factor = factor }, MAX_RADIUS * factor + EFFECT_PADDING)

	local function step()
		if self.Run ~= run then
			return
		end
		local now = os.clock()
		local elapsed = now - began
		if elapsed > DURATION or entity.Dead then
			self:Stop()
			return
		end

		local radius = if elapsed <= GROW_TIME
			then MAX_RADIUS * (elapsed / GROW_TIME) * factor
			else (MAX_RADIUS - MAX_RADIUS * ((elapsed - GROW_TIME) / SHRINK_TIME)) * factor

		for target, entry in self.Covered do
			if target.Dead or now - entry.LastSeen > LINGER then
				self:Uncover(target)
			end
		end

		if radius > 0 then
			for _, target in Hitbox.Sphere(origin, radius, entity) do
				if not AFFECTS_NPCS and not target.Player then
					continue
				end
				local height = target.Root.Position.Y - origin.Y
				if height >= MIN_HEIGHT and height <= MAX_HEIGHT then
					self:Cover(target, damage)
				end
			end
		end

		task.delay(STEP, step)
	end
	step()
end

-- Ends the pool's server side and lifts every cover it holds.
function MochiWasteland:Stop()
	self.Run = (self.Run or 0) + 1
	local covered = self.Covered
	if covered then
		for target in covered do
			self:Uncover(target)
		end
	end
	self.Covered = {}
end

function MochiWasteland:OnInterrupt()
	self:Stop()
end

return MochiWasteland
