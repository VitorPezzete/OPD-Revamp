--!strict
--[[
	Float fruit - Levitate (toggle): free flight steered by the camera.

	Top speed (studs/s): 25 * (30 / 9 + melee level / 450 * melee affinity)
	The legacy client added (30 / 9 + level / 50 / 9 * affinity) to its velocity every
	frame while keeping 96% of the previous one, which settles at 25 times that step.

	The server only owns the state and the speed (the status value). The flight runs on
	the owner's client (Effects/Status/FloatLevitating).

	Float and Levitate replace each other; see Float for why the entity statuses, not
	self.Active, hold the state.

	Legacy problems fixed here:
	- The client computed its own speed from its own copy of the level and affinity.
	- The server cloned a part, a BodyGyro and a BodyVelocity into the character and
	  left them there on death.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local FLOATING = "FloatFloating"
local ASCENDING = "FloatAscending"
local LEVITATING = "FloatLevitating"

local BASE_STEP = 30 / 9
local LEVELS_PER_STEP = 50 * 9
-- 1 / (1 - 0.96): what the legacy per-frame accumulation converges to.
local STEPS_AT_TOP_SPEED = 25

local Levitate = Ability.extend()

-- Legacy flight disabler (Server.Modules.FlightLock): the Float client watched the
-- counter for Levitate only (Float.client 88-91, 266-271), never for Float / Ascend, and
-- no Float power raised it. So a power of the OTHER fruit lands Levitate for 3 s.
Levitate.Flight = true

function Levitate:CanBegin(): boolean
	-- Turning it off is always allowed; turning it on is not while seated, rooted,
	-- flight-locked or under NoMovement (DF Float.server 222).
	return self.Entity:HasStatus(LEVITATING)
		or not (self.Entity.Humanoid.Sit or self.Entity:IsRooted() or self:IsFlightBlocked())
end

function Levitate:OnBegin()
	local entity = self.Entity
	if entity:HasStatus(LEVITATING) then
		self:OnInterrupt()
		return
	end

	entity:ClearStatus(ASCENDING)
	entity:ClearStatus(FLOATING)

	local step = BASE_STEP + self:GetLevel("Melee") / LEVELS_PER_STEP * self:GetAffinity("Melee")
	-- The status value is the top speed the owner's client flies at.
	entity:SetStatus(LEVITATING, step * STEPS_AT_TOP_SPEED, nil, true)
end

function Levitate:OnInterrupt()
	self.Entity:ClearStatus(LEVITATING)
end

return Levitate
