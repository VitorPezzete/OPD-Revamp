--!strict
--[[
	Gum fruit - Gatling (Jet Gatling in 2nd Gear): while the key is held, a stream of
	stretch punches with alternating arms. The user stands still while firing.

	Each punch is the stretch punch of _Shared (same reach and damage as Pistol).
	With L = melee level:

	                 punch time   seconds between punches   melee level
	Gatling            0.15 s          0.25 - L / 5000            75
	Jet Gatling        0.10 s          0.14 - L / 5000           175

	The interval is floored at MIN_INTERVAL (the legacy Jet value reaches 0.04 s at level
	500, 25 projectiles a second).

	A Pistol or Bazooka arm that is still out keeps Gatling from starting and ends a
	running stream (_Shared: GumArmsOut).

	Who drives it. The legacy client looped `FireServer` at that interval and the server
	accepted a punch every millisecond from anyone. The stream is a server tick now,
	started by the press and stopped by the release / OnInterrupt; it only exists while
	the key is held. The client's part is the aim: Effects.Status.GumGatling sends the
	mouse position a few times a second as the ability's secondary input (OnAction), so
	the stream follows the cursor like the legacy one did, and holds the owner's character
	in place, turned towards each punch (the legacy BodyPosition and BodyGyro). Every
	client hides both real arms for as long as the status is on.

	Status GumGatling (replicated): "<fruit slot>|<ability slot>".
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local STATUS = "GumGatling"
local ROOT = "GumGatling"
local JET_LEVEL = 175

local PUNCH_TIME = 0.15
local JET_PUNCH_TIME = 0.1
local INTERVAL = 0.25
local JET_INTERVAL = 0.14
local INTERVAL_LEVEL_DIVISOR = 5000
local MIN_INTERVAL = 0.05
-- Seconds the arm stays out before coming back.
local HOLD = 0.1

local Gatling = Ability.extend()

function Gatling:CanBegin(): boolean
	local entity = self.Entity
	return not self.Active
		and not Shared.IsBusy(entity)
		and not Shared.AreArmsOut(entity)
		and not entity.Humanoid.Sit
		and Shared.MeetsGearLevel(self, JET_LEVEL)
end

function Gatling:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity

	Shared.MarkMove(entity)
	self.Active = true
	self.Aim = input.AimPosition
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetRooted(ROOT, true)
	entity:SetStatus(STATUS, `{self.Context.FruitSlot}|{self.Context.Definition.Slot}`, nil, true)

	local function fire()
		if self.Run ~= run or not self.Active or entity.Dead then
			return
		end
		-- The gear can change mid-stream; a Jet stream that is not unlocked simply stops.
		-- So does a stream whose user throws a Pistol or a Bazooka.
		if entity.Humanoid.Sit or Shared.AreArmsOut(entity) or not Shared.MeetsGearLevel(self, JET_LEVEL) then
			self:OnInterrupt()
			return
		end

		local jet = Shared.IsSecondGear(entity)
		self.UseLeft = not self.UseLeft
		Shared.Punch(self, self.Aim, {
			Hand = if self.UseLeft then "Left" else "Right",
			Time = if jet then JET_PUNCH_TIME else PUNCH_TIME,
			Hold = HOLD,
		})

		local interval = (if jet then JET_INTERVAL else INTERVAL) - self:GetLevel("Melee") / INTERVAL_LEVEL_DIVISOR
		task.delay(math.max(interval, MIN_INTERVAL), fire)
	end
	fire()
end

-- Aim update from the owner's client while the key is held.
function Gatling:OnAction(input: Ability.AbilityInput)
	self.Aim = input.AimPosition
end

function Gatling:OnEnd()
	if self.Active then
		self:OnInterrupt()
	end
end

function Gatling:OnInterrupt()
	self.Active = false
	-- Invalidates the pending punch of the stream that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:SetRooted(ROOT, false)
	self.Entity:ClearStatus(STATUS)
end

return Gatling
