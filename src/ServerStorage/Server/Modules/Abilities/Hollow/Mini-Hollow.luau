--!strict
--[[
	Hollow fruit - Mini-Hollow: summons small explosive ghosts, then sends them.

	Create:  floor(20 * (sniper level / cap) * sniper affinity) ghosts, one every 0.1 s.
	         Each comes out of the caster (or of the projected ghost body) and drifts to
	         a spot within 3 studs of it, 1 to 2 studs up.
	         5 s before another batch can be created, 1 s after a send.
	         A character takes 87.5 * (level / cap) * affinity from every ghost it
	         touches, and that ghost is used up.
	Send:    press again. The ghosts fly at 70 studs per second to the closest character
	         within 300 studs and each one deals 75 * (level / cap) * affinity
	         ("Special", not dodgeable) when they get within 10 studs.

	The mechanics shared with Negative Hollow are in HollowSwarm.

	Each ghost is its own hit, as before (so per-hit modifiers see the same amounts),
	delivered together when the group arrives; the legacy ghosts arrived within a few
	frames of each other.
]]
local ServerStorage = game:GetService("ServerStorage")

local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local HollowSwarm = require(script.Parent.HollowSwarm)

local SEARCH_RADIUS = 300
local SPEED = 70
local CONTACT_DAMAGE = 87.5
local ARRIVE_DAMAGE = 75

local function getPower(self: any): number
	return self:GetLevelScale("Sniper") * self:GetAffinity("Sniper")
end

return HollowSwarm.extend({
	Status = "HollowMinis",
	Kind = "Mini",
	AmountBase = 20,
	SpawnInterval = 0.1,
	HoverRadius = 3,
	HoverLow = 1,
	HoverHigh = 2,
	TouchRadius = 0.75,
	CreateCooldown = 5,
	SendCooldown = 1,
	Charged = false,
	Reach = 10,

	OnContact = function(self: any, target): boolean
		self:Damage(target, CONTACT_DAMAGE * getPower(self), "Special", nil, false)
		return true
	end,

	PickTarget = function(self: any, origin: Vector3, _aim: Vector3, _charge: number?): HollowSwarm.Flight?
		local closest = Hitbox.Closest(Hitbox.Sphere(origin, SEARCH_RADIUS, self.Entity), origin)
		if not closest then
			return nil
		end
		return { Target = closest, Speed = SPEED, Power = ARRIVE_DAMAGE * getPower(self) }
	end,

	OnArrive = function(self: any, flight: HollowSwarm.Flight, count: number)
		for _ = 1, count do
			if flight.Target.Dead then
				break
			end
			self:Damage(flight.Target, flight.Power, "Special", nil, false)
		end
	end,
})
