--!strict
--[[
	Barrier fruit - Barrier Body (toggle): the user encases itself in barriers.

	While active (at most 20 s):
	- every hit is negated (DamageModifiers/BarrierBody, gated on the BarrierBody status);
	- the user cannot walk;
	- every power of the user is sealed (both fruits, haki toggles);
	- the user holds the barrier pose (BarrierActive, see _Construct).
	It cannot be raised again for 5 s after it was raised or dropped.

	KeepThroughStun: a stun does not drop the body, as in the legacy game (the damage is
	negated but stuns still land). A stunned user cannot raise it.

	Turning it off: a sealed character's key presses never reach an ability, but key
	releases always do. So the press that raises the body has its release ignored, and
	any later release of the key (the press was dropped by the seal) lowers it.

	The seal is the framework's AbilitiesDisabled status, set directly with a marker
	value instead of through AbilityService:SetSealed: SetSealed interrupts every
	ability of the character, this one included. The marker lets OnInterrupt remove
	only its own seal, so being sealed by someone else (Hobby, seastone) while the body
	is up is not undone when the body drops.

	Legacy problems fixed here:
	- `bodytime` (the 20 s timer id) was one script-level variable.
	- A `while usingBody.Value` loop re-set DF_Disabled four times a second.
	- Death left the armor parts and the UsingBarrierBody flag on the corpse.

	As in the legacy game, raising the body only blocks new presses: what is already
	running (a standing Wall / Room / Prison, the Bat on the arm, toggles of the second
	fruit) stays as it is.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local Construct = require(script.Parent._Construct)

-- Replicated (value: fruit colors) and read by the damage modifier and the root.
local STATUS = "BarrierBody"
local SEAL_STATUS = AbilityConfig.Status.AbilitiesDisabled
local SEAL_MARK = "BarrierBody"

local MAX_SECONDS = 20
local COOLDOWN = 5
-- A release this soon after raising is the same key press bouncing.
local MIN_SECONDS = 0.25

local BarrierBody = Ability.extend()

BarrierBody.KeepThroughStun = true

function BarrierBody:CanBegin(): boolean
	if self.Active then
		return true
	end
	return not self.Entity:HasStatus(Construct.StunStatus) and os.clock() - (self.LastChange or -math.huge) >= COOLDOWN
end

function BarrierBody:OnBegin()
	-- Only reachable while active if something else lifted the seal.
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity

	self.Active = true
	self.IgnoreRelease = true
	self.LastChange = os.clock()
	self.Epoch = (self.Epoch or 0) + 1
	local epoch = self.Epoch

	entity:SetStatus(STATUS, self:GetColorString(), nil, true)
	entity:SetRooted(STATUS, true)
	entity:SetStatus(SEAL_STATUS, SEAL_MARK, nil, true)
	Construct.SetActive(entity)

	task.delay(MAX_SECONDS, function()
		if self.Active and self.Epoch == epoch then
			self:OnInterrupt()
		end
	end)
end

function BarrierBody:OnEnd()
	if self.IgnoreRelease then
		self.IgnoreRelease = false
		return
	end
	if self.Active and os.clock() - (self.LastChange or 0) >= MIN_SECONDS then
		self:OnInterrupt()
	end
end

function BarrierBody:OnInterrupt()
	local wasActive = self.Active
	self.Active = false
	self.IgnoreRelease = false
	self.Epoch = (self.Epoch or 0) + 1

	local entity = self.Entity
	entity:ClearStatus(STATUS)
	entity:SetRooted(STATUS, false)
	if entity:GetStatus(SEAL_STATUS) == SEAL_MARK then
		entity:ClearStatus(SEAL_STATUS)
	end

	if wasActive then
		Construct.ClearActive(entity)
		self.LastChange = os.clock()
		self:StartCooldown(COOLDOWN)
	end
end

return BarrierBody
