--!strict
--[[
	Bomb fruit - Bomb Wave (charged): a chain of five growing explosions marching from the
	casting hand towards the aim point (hands alternate with Bomb Punch, see _Shared).

	Charge: 20 per second held, 4 to 100 (timed on the server).
	With m = sniper affinity, s = sniper level / cap, c = charge / 100 and
	L = 300 * m * s * c, blast i (1 to 5, one every 0.1 s):
	- centre = previous centre + direction * L * i / 25 (the chain starts at the hand),
	  so the last one sits 0.6 * L away;
	- radius = L * i / 18 (root distance); the ball drawn is a 0.1 * i stud part whose mesh
	  is scaled by L (see _Shared);
	- damage = 1000 * m * s * c, Special, not dodgeable; doubled with armament haki at
	  release. A target is hit by at most one blast of the chain.

	Everything (origin, direction, haki) is fixed at release, as in the legacy game. The
	four pending blasts are delays cancelled by OnInterrupt.

	Legacy problem fixed here: the remote handler itself slept through the chain
	(wait(0.1) x 5) holding shared script-level variables, so two players, or a second
	cast, could overwrite each other's affinity and charge mid-wave.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local CHARGE_RATE = 20
local GROW_SECONDS = 3
local LENGTH = 300
local DAMAGE = 1000
local BLASTS = 5
local BLAST_INTERVAL = 0.1
local STEP_DIVISOR = 25
local RADIUS_DIVISOR = 18
-- Blast i is drawn on a part of 0.1 * i studs.
local BALL_PART_STEP = 0.1

local BombWave = Ability.extend()

function BombWave:CanBegin(): boolean
	return not Shared.IsCharging(self.Entity)
end

function BombWave:OnBegin()
	-- The legacy sphere on the hand grew with the MELEE level and affinity for this one too.
	Shared.BeginCharge(self, "Wave", "Melee", GROW_SECONDS, Shared.ChargeMax / CHARGE_RATE)
end

function BombWave:OnEnd(input: Ability.AbilityInput)
	local charge = Shared.EndCharge(self, CHARGE_RATE)
	if not charge then
		return
	end

	local entity = self.Entity
	local hand = Shared.GetHand(entity)
	Shared.SwapHand(entity)
	local power =self:GetAffinity("Sniper") * self:GetLevelScale("Sniper") * (charge / Shared.ChargeMax)
	local length = LENGTH * power
	local damage = DAMAGE * power
	local haki = self.Services.Haki:IsArmamentActive(entity)
	if haki then
		damage *= Shared.HakiMultiplier
	end

	local direction = Shared.AimDirection(entity, input.AimPosition)
	local origin = Shared.LimbPosition(entity, hand .. " Arm")
	local alreadyHit: { [CharacterEntity]: boolean } = {}

	self.Run = (self.Run or 0) + 1
	local run = self.Run

	local travelled = 0
	for index = 1, BLASTS do
		travelled += length * index / STEP_DIVISOR
		local center = origin + direction * travelled
		local radius = length * index / RADIUS_DIVISOR
		-- The blast color runs from the first fruit color to the second along the chain.
		local blend = (index - 1) / (BLASTS - 1)

		if index == 1 then
			Shared.Explode(self, center, radius, damage, haki, blend, "Power5", alreadyHit, {
				Scale = length,
				PartSize = BALL_PART_STEP * index,
				Release = "Wave",
				Hand = hand,
				Aim = input.AimPosition,
			})
		else
			task.delay((index - 1) * BLAST_INTERVAL, function()
				if self.Run == run and not entity.Dead then
					Shared.Explode(self, center, radius, damage, haki, blend, "Power5", alreadyHit, {
						Scale = length,
						PartSize = BALL_PART_STEP * index,
					})
				end
			end)
		end
	end
end

function BombWave:OnInterrupt()
	-- Drops the blasts of a wave still marching.
	self.Run = (self.Run or 0) + 1
	Shared.CancelCharge(self)
end

return BombWave
