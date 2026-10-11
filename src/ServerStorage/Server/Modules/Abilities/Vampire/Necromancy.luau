--!strict
--[[
	Vampire fruit - Necromancy: raises bats.

	Tap, aiming at a soul:  the soul becomes a bat holding the dead player's max health
	                        (at most 6 bats; a full vampire leaves the soul alone).
	Hold 0.8 s and release: toggles the bats' attack mode. In attack mode the next
	                        Bat Swarm carries one bat with it (see Bat Swarm).

	Bats are also raised directly by killing a player; bats, souls and the kill hook
	are in VampireShared. A soul is picked when it lies within 6 studs of the aim
	point: the VampireSoul client effect makes the soul something the aim ray stops on.

	The hold is timed here (the legacy client measured it and sent "ChangeMode"): the
	charge bar ran at 25 per second and the mode changed above 20 of 25.

	Legacy problems fixed here:
	- The client sent the soul instance it clicked; the server trusted it.
	- Every conversion connected a new Humanoid.Died handler that was never removed.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local VampireShared = require(script.Parent.VampireShared)

local SOUL_RADIUS = 6
local CHARGE_RATE = 25
local CHARGE_MIN = 4
local CHARGE_MAX = 25
local MODE_CHARGE = 20

local Necromancy = Ability.extend()

function Necromancy:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	self:BeginCharge(CHARGE_MAX / CHARGE_RATE)

	if VampireShared.GetBatCount(entity) >= VampireShared.MaxBats then
		return
	end
	local soul = VampireShared.TakeSoulNear(input.AimPosition, SOUL_RADIUS)
	if soul then
		VampireShared.AddBat(entity, soul.Health)
	end
end

function Necromancy:OnEnd()
	local charge = self:EndCharge(CHARGE_RATE, CHARGE_MIN, CHARGE_MAX)
	if not charge or charge <= MODE_CHARGE then
		return
	end

	local entity = self.Entity
	local status = VampireShared.Status.BatAttack
	if entity:HasStatus(status) then
		entity:ClearStatus(status)
	else
		entity:SetStatus(status, true, nil, true)
	end
end

function Necromancy:OnInterrupt()
	-- The attack mode is not a running state of this ability: like the bats, it stays
	-- through a stun and goes with the character (VampireShared.Unregister).
	self.ChargeStart = nil
end

return Necromancy
