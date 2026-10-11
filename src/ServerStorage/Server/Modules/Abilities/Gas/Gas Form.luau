--!strict
--[[
	Gas fruit - Gas Form (toggle): the body turns into gas and flies, passing through
	the map.

	The server owns the state and the collision group. The replicated status carries the
	top speed and the fruit colors ("<speed>|<colors>"); the owner's client flies the
	character and every client draws the gas body (Effects.Status.GasFlying).

	Top speed. The legacy client ran, every rendered frame:
		momentum = momentum * 0.96 + direction * (40 / 9 + defense level / 50 / 9 * melee affinity)
	which settles at 25 times the added term (1 / (1 - 0.96)), so
		top speed = 25 * (40 / 9 + defense level / 450 * melee affinity) studs per second
	(111 at level 0, 167 at level 500 with affinity 2). Defense level with the melee
	affinity is what the legacy script read, odd as it is for a Melee ability; kept. So
	is the affinity it read: always the one of fruit slot 1 (both branches of the legacy
	client used DFT1Melee), whichever slot holds the Gas fruit.

	While in gas form the body parts are in a collision group that does not collide with
	the map (legacy "NoCollideHollow"), restored on landing.

	Legacy problems fixed here:
	- The server toggled on any message. The "flight disabler" fired the same toggle, so
	  using another Gas ability while on the ground turned the gas form ON.
	- Flight disabler (Server.Modules.FlightLock, `Flight = true`): any power of the
	  character that raised the legacy counter lands the gas form and locks it for 3 s.
	  The legacy server also refused the take-off under NoMovement (DF Gas.server 105).
	- Gas parts, body movers and the collision group were only undone by the toggle,
	  never on death, so a respawn could keep a stale Fly counter.
	- The nested loops set the collision group and cloned the gas parts 7 x 6 times.
]]
local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "GasFlying"
local GROUP = "GasFormNoCollide"

local BASE_GAIN = 40 / 9
local GAIN_PER_LEVEL = 1 / 450
-- Steady state of "momentum * 0.96 + gain" is gain / (1 - 0.96).
local GAIN_TO_SPEED = 25

local BODY_PARTS = { "Head", "Torso", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "HumanoidRootPart" }

if not PhysicsService:IsCollisionGroupRegistered(GROUP) then
	PhysicsService:RegisterCollisionGroup(GROUP)
end
PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)

local GasForm = Ability.extend()

-- The legacy client waited 0.5 s between two presses.
GasForm.Debounce = 0.5
GasForm.Flight = true

function GasForm:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function GasForm:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local affinity = self.Context.Data.Data.Affinities.DF1.Melee
	local gain = BASE_GAIN + self:GetLevel("Defense") * GAIN_PER_LEVEL * affinity
	local speed = math.round(gain * GAIN_TO_SPEED)

	self.Active = true

	local previousGroups: { [BasePart]: string } = {}
	for _, partName in BODY_PARTS do
		local part = entity.Model:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			previousGroups[part] = part.CollisionGroup
			part.CollisionGroup = GROUP
		end
	end
	self.PreviousGroups = previousGroups

	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)

	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function GasForm:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end

	local previousGroups: { [BasePart]: string }? = self.PreviousGroups
	if previousGroups then
		self.PreviousGroups = nil
		for part, group in previousGroups do
			part.CollisionGroup = group
		end
	end
	self.Entity:ClearStatus(STATUS)
end

return GasForm
