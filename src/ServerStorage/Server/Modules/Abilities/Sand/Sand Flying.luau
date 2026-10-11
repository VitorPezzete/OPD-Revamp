--!strict
--[[
	Sand fruit - Sand Flying (toggle): fly on two streams of sand coming out of the legs.

	The server only owns the state. The replicated status carries the flight speed and
	the fruit colors ("<speed>|<colors>"); the owner's client flies the character and
	every client draws the sand (Effects.Status.SandFlying).

	Speed: the legacy client drove a BodyPosition (ReplicatedStorage.Resources.FlareJet,
	shared with Flare, Smoke and Spin) whose power was
		P = (60 + melee level / 200) * melee affinity * CoreModule:GetBaseSpeed()
	aimed 10000 studs ahead. A BodyPosition that far from its goal settles at the speed
	where P * 10000 = D * speed; FlareJet (Assets.Models.Fruits._Shared) has D = 1250, so
	the flight speed is 8 * P studs per second: 480 at affinity 1, 1000 at level 500
	with affinity 2. GetBaseSpeed (a client-side global speed setting) is not ported and
	counts as 1.

	It ends when the key is pressed again, the humanoid sits, or a power of the character
	that raised the legacy "flight disabler" is used, which also locks it for 3 seconds
	(Server.Modules.FlightLock, `Flight = true`). The legacy server also refused the
	take-off under the NoMovement flag (DF Sand.server 69).

	Legacy problems fixed here:
	- The client decided when it was flying and told the server "Fly" / "Land" with its
	  own melee level as an argument (an exploit check killed the player if it was too
	  high). The leg particles were server instances removed only by "Land", never on
	  death or seal.
	- `Fly.Value += 1` / `-= 1` could drift when a "Land" was lost.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Shared = require(script.Parent._Shared)

local STATUS = Shared.FLIGHT_STATUS

local BASE_POWER = 60
local LEVELS_PER_POWER = 200
-- Goal distance / damping of the legacy BodyPosition: 10000 / 1250.
-- The legacy mover gives 10000 / 1250 = 8 studs/s per unit of power, but that was a 4x
-- speed-up of the copy the dump was taken from: the game's own value is a quarter of it.
local SPEED_PER_POWER = 10000 / 1250 / 4

local SandFlying = Ability.extend()

SandFlying.Flight = true

function SandFlying:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function SandFlying:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local power = (BASE_POWER + self:GetLevel("Melee") / LEVELS_PER_POWER) * self:GetAffinity("Melee")
	local speed = math.round(power * SPEED_PER_POWER)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)

	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)
end

function SandFlying:OnInterrupt()
	self.Active = false
	if self.SeatConnection then
		self.SeatConnection:Disconnect()
		self.SeatConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return SandFlying
