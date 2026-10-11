--!strict
--[[
	Love fruit - Petrify (toggle): the user turns itself to stone.

	While petrified:
	- hits are reduced to (1 - 0.25 - 0.325 * sniper affinity) of their amount
	  (DamageModifiers/LoveStunned);
	- the user cannot walk and all of its powers are sealed;
	- it lasts until toggled off or until 5000 * (defense level / cap) * defense
	  affinity damage (counted before the reduction) has been received.
	It cannot be raised again for 5 s after it was raised or dropped by its user; a
	stone broken by damage starts no cooldown of its own, as in the legacy game.

	The seal and the "release toggles it off" input follow Barrier Body: a sealed
	character's key presses never reach an ability but its releases do, and the seal is
	the AbilitiesDisabled status written with a marker value so that only this ability's
	own seal is lifted when the stone drops.

	Legacy problems fixed here:
	- The 5 s cooldown table was keyed by player inside a per-character script and the
	  timer was a NumberValue set to 9999 and decremented once a second.
	- Death left the stone parts and the LoveStunned flag on the corpse.
	Changed: raising the stone interrupts the user's other running abilities; the legacy
	seal only blocked new presses.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AbilityConfig = require(ReplicatedStorage.Shared.Configs.AbilityConfig)
local Ability = require(ServerStorage.Server.Classes.Ability)
local Love = require(script.Parent._Shared)

local ROOT_NAME = "LovePetrify"
local SEAL_STATUS = AbilityConfig.Status.AbilitiesDisabled
local SEAL_MARK = "LovePetrify"

local THRESHOLD = 5000
local COOLDOWN = 5
-- A release this soon after raising is the same key press bouncing.
local MIN_SECONDS = 0.25

local Petrify = Ability.extend()

-- A stun from someone else (ice, toy...) did not break the stone in the legacy game.
-- Being petrified by another Love user still does: its seal interrupts everything.
Petrify.KeepThroughStun = true

function Petrify:CanBegin(): boolean
	return self.Active or os.clock() - (self.LastChange or -math.huge) >= COOLDOWN
end

function Petrify:OnBegin()
	-- Only reachable while active if something else lifted the seal.
	if self.Active then
		self.LastChange = os.clock()
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	local threshold = THRESHOLD * self:GetLevelScale("Defense") * self:GetAffinity("Defense")
	if threshold <= 0 or entity:HasStatus(Love.STATE) then
		return
	end

	-- Ends everything else that is running (this object included, which is idle).
	self.Services.Ability:Interrupt(entity)

	self.Active = true
	self.IgnoreRelease = true
	self.LastChange = os.clock()

	local state: Love.State = {
		Threshold = threshold,
		SniperAffinity = self:GetAffinity("Sniper"),
		Self = true,
		Owner = entity,
	}
	entity:SetStatus(Love.STATE, state)
	entity:SetStatus(Love.STATUS, self:GetColorString(), nil, true)
	entity:SetRooted(ROOT_NAME, true)
	entity:SetStatus(SEAL_STATUS, SEAL_MARK, nil, true)
end

function Petrify:OnEnd()
	if self.IgnoreRelease then
		self.IgnoreRelease = false
		return
	end
	if self.Active and os.clock() - (self.LastChange or 0) >= MIN_SECONDS then
		self.LastChange = os.clock()
		self:OnInterrupt()
	end
end

function Petrify:OnInterrupt()
	local wasActive = self.Active
	self.Active = false
	self.IgnoreRelease = false

	local entity = self.Entity
	-- Only this ability's own stone: a victim state written by another Love user stays.
	local state: Love.State? = entity:GetStatus(Love.STATE)
	if state and state.Self then
		entity:ClearStatus(Love.STATE)
		entity:ClearStatus(Love.STATUS)
	end
	entity:SetRooted(ROOT_NAME, false)
	if entity:GetStatus(SEAL_STATUS) == SEAL_MARK then
		entity:ClearStatus(SEAL_STATUS)
	end

	if wasActive then
		-- LastChange is now for a drop by the user, the moment it was raised otherwise.
		local remaining = COOLDOWN - (os.clock() - (self.LastChange or 0))
		if remaining > 0 then
			self:StartCooldown(remaining)
		end
	end
end

return Petrify
