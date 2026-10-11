--!strict
--[[
	Smoke fruit - Fly (toggle): fly on two columns of smoke coming out of the legs.

	The server only owns the state. The replicated status carries the flight speed and
	the fruit colors ("<speed>|<colors>"); the owner's client flies the character and
	every client draws the smoke (Effects.Status.SmokeFlying).

	Speed: the legacy client drove a BodyPosition (ReplicatedStorage.Resources.FlareJet,
	shared with Flare and Spin) whose power was
		P = 60 + melee level / 50 * melee affinity
	aimed 10000 studs ahead. A BodyPosition that far from its goal settles at the speed
	where P * 10000 = D * speed; FlareJet (Assets.Models.Fruits._Shared) has D = 1250, so
	the flight speed is 8 * P studs per second: 480 at level 0, 640 at level 500 with
	affinity 2.

	It ends when the key is pressed again, the humanoid sits, or the character uses an
	ability that grounded flights in the legacy game, which also locks it for 3 seconds
	(the "flight disabler" counter was shared by both fruits of the character:
	Server.Modules.FlightLock, `Flight = true`). Of the Smoke abilities only Whiteout
	Burst did; White Out and White Fist can be used while flying. The legacy Smoke server
	never looked at the NoMovement flag (IsFlightBlocked(true)).

	Legacy quirk kept (it decides the flight speed): the affinity was picked with
	`if DevilFruit == "Flare" then DFT1Melee else DFT2Melee`, a copy of the Flare script.
	The melee affinity used is therefore the one of fruit slot 2, whichever slot holds
	Smoke, unless slot 1 holds Flare (then slot 1's).

	Legacy problems fixed here:
	- The client decided when it was flying and told the server "Fly" / "Land"; a "Land"
	  without a "Fly" indexed a nil sound and threw.
	- Leg particles and the loop sound were server instances removed only by "Land",
	  never on death or seal.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "SmokeFlying"

local BASE_POWER = 60
local LEVELS_PER_POWER = 50
-- Goal distance / damping of the legacy BodyPosition: 10000 / 1250.
-- The legacy mover gives 10000 / 1250 = 8 studs/s per unit of power, but that was a 4x
-- speed-up of the copy the dump was taken from: the game's own value is a quarter of it.
local SPEED_PER_POWER = 10000 / 1250 / 4

local Fly = Ability.extend()

Fly.Flight = true

function Fly:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked(true))
end

function Fly:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local data = self.Context.Data.Data
	local affinity = if data.DevilFruits.Slot1.Name == "Flare" then data.Affinities.DF1.Melee else data.Affinities.DF2.Melee
	local power = BASE_POWER + self:GetLevel("Melee") / LEVELS_PER_POWER * affinity
	local speed = math.round(power * SPEED_PER_POWER)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function Fly:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return Fly
