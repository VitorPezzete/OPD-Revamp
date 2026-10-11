--!strict
--[[
	Hollow fruit - Negative Hollow: summons ghosts, then sends them to make a target
	Negative (stunned; 20 s cooldown per victim, see HollowNegative).

	Create:  floor(10 * (sniper level / cap) * sniper affinity) ghosts, one every 0.5 s.
	         Each comes out of the caster (or of the projected ghost body) and drifts to
	         a spot within 10 studs of it, 3 to 7 studs up.
	         5 s before another batch can be created, 1 s after a send.
	         A character a ghost touches (on its way out or hovering) becomes Negative
	         for 3.5 * (level / cap) * affinity seconds; the ghost is not used up.
	Send:    hold and release the key again (charge rate 25, 4-15).
	         - Normal: closest character within 500 studs of the ghosts; speed
	           75 + 25 * affinity; Negative for 3.5 * (level / cap) * affinity s.
	         - Full charge while aiming at a character: that character, at any distance;
	           speed 100 + 50 * affinity; Negative for 4.5 * (level / cap) * affinity s.
	         The debuff lands when the ghosts get within 20 studs.

	The mechanics shared with Mini-Hollow are in HollowSwarm.

	Legacy problems fixed here:
	- The client sent the charge amount and the targeted part.
	- "SendHollows" skipped the sealed check that "CreateHollows" had.
]]
local ServerStorage = game:GetService("ServerStorage")

local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local HollowNegative = require(script.Parent.HollowNegative)
local HollowSwarm = require(script.Parent.HollowSwarm)

local SEARCH_RADIUS = 500
local AIM_RADIUS = 5

local function getPower(self: any): number
	return self:GetLevelScale("Sniper") * self:GetAffinity("Sniper")
end

return HollowSwarm.extend({
	Status = "HollowHollows",
	Kind = "Hollow",
	AmountBase = 10,
	SpawnInterval = 0.5,
	HoverRadius = 10,
	HoverLow = 3,
	HoverHigh = 7,
	TouchRadius = 1.5,
	CreateCooldown = 5,
	SendCooldown = 1,
	Charged = true,
	Reach = 20,

	OnContact = function(self: any, target): boolean
		HollowNegative.Apply(self.Services.Status, target, 3.5 * getPower(self))
		return false
	end,

	PickTarget = function(self: any, origin: Vector3, aim: Vector3, charge: number?): HollowSwarm.Flight?
		local affinity = self:GetAffinity("Sniper")

		if charge and charge >= HollowSwarm.ChargeMax then
			local aimed = Hitbox.Closest(Hitbox.Sphere(aim, AIM_RADIUS, self.Entity), aim)
			if aimed then
				return { Target = aimed, Speed = 100 + 50 * affinity, Power = 4.5 * getPower(self) }
			end
		end

		local closest = Hitbox.Closest(Hitbox.Sphere(origin, SEARCH_RADIUS, self.Entity), origin)
		if not closest then
			return nil
		end
		return { Target = closest, Speed = 75 + 25 * affinity, Power = 3.5 * getPower(self) }
	end,

	OnArrive = function(self: any, flight: HollowSwarm.Flight, _count: number)
		HollowNegative.Apply(self.Services.Status, flight.Target, flight.Power)
	end,
})
