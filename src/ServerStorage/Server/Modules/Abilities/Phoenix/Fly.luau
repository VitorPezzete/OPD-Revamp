--!strict
--[[
	Phoenix fruit - Fly (toggle): free flight on wings of blue flame.

	The server only owns the state. The replicated status carries the flight speed and
	the fruit colors ("<speed>|<colors>"); the owner's client flies the character and
	every client draws the wings (Effects.Status.PhoenixFlying).

	Speed: the legacy client is a copy of Flare's Jet, a BodyPosition of power
		P = 60 + melee level / 50 * melee affinity * second affinity
	chased 10000 studs ahead. That BodyPosition is the "FlareJet" template (D = 1250), so
	it settled at P * 10000 / 1250 = 8 * P studs per second: 480 studs/s at level 0, 800 at
	level 500 with both affinities at 2. The client CoreModule "base speed" (always 1) is
	not applied.

	The second affinity is a leftover of the copy, kept because it is the speed players
	had: after multiplying by the fruit's own melee affinity the script still tested
	`DevilFruit == "Flare"` and multiplied again by the melee affinity of slot 1 when the
	first fruit was Flare, of slot 2 otherwise. So a Phoenix in slot 2 flies on its own
	affinity squared, and one in slot 1 on its affinity times the one of slot 2.

	Legacy problems fixed here:
	- The client decided when it was flying and told the server "Fly" / "Land"; a "Land"
	  without a "Fly" drove the shared Fly counter below zero.
	- Wings were server parts recolored by a per-frame loop each.

	Soar and Fly replace each other (the Used signal below). Flight disabler
	(Server.Modules.FlightLock, `Flight = true`): any power of the character that raised
	the legacy counter (Phoenix Burst / Pulse, or a power of the other fruit) lands both
	and locks them for 3 s. The legacy server also refused both under the NoMovement flag
	(DF Phoenix.server 177, 236). The status is the source of truth.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)

local STATUS = "PhoenixFlying"
-- The sibling toggle this one replaces and is replaced by.
local SIBLING = "Soar"

local BASE_POWER = 60
local POWER_PER_LEVEL = 1 / 50
-- Terminal speed of the legacy BodyPosition: target distance / damping.
-- The legacy mover gives 10000 / 1250 = 8 studs/s per unit of power, but that was a 4x
-- speed-up of the copy the dump was taken from: the game's own value is a quarter of it.
local SPEED_PER_POWER = 10000 / 1250 / 4

local Fly = Ability.extend()

Fly.Flight = true

function Fly:CanBegin(): boolean
	local entity = self.Entity
	-- Landing is always allowed; taking off is not while seated, rooted or locked.
	return entity:HasStatus(STATUS) or not (entity.Humanoid.Sit or entity:IsRooted() or self:IsFlightBlocked())
end

function Fly:OnBegin()
	local entity = self.Entity
	local wasFlying = entity:HasStatus(STATUS)

	self:OnInterrupt()
	if wasFlying then
		return
	end

	local data = self.Context.Data.Data
	local second = if data.DevilFruits.Slot1.Name == "Flare" then data.Affinities.DF1 else data.Affinities.DF2
	local power = BASE_POWER
		+ self:GetLevel("Melee") * POWER_PER_LEVEL * self:GetAffinity("Melee") * second.Melee
	local speed = math.round(power * SPEED_PER_POWER)

	self.Active = true
	entity:SetStatus(STATUS, `{speed}|{self:GetColorString()}`, nil, true)
	self.SeatConnection = entity.Humanoid.Seated:Connect(function(seated: boolean)
		if seated then
			self:OnInterrupt()
		end
	end)

	local fruitName = self.Context.FruitName
	self.UsedConnection = self.Services.Ability.Used:Connect(function(user: any, usedFruit: string, usedAbility: string)
		if user == entity and usedFruit == fruitName and usedAbility == SIBLING then
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
	if self.UsedConnection then
		self.UsedConnection:Disconnect()
		self.UsedConnection = nil
	end
	self.Entity:ClearStatus(STATUS)
end

return Fly
