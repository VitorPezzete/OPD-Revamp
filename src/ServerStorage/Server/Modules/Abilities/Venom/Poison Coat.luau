--!strict
--[[
	Venom fruit - Poison Coat (toggle, legacy `UsingVenomBody`): the body is coated in
	poison and poisons whoever touches it.

	With f = defense affinity * (defense level / cap), every contact applies VenomDoT:
	- normally        350 * f per hit, floor(10 * f) hits, Normal speed;
	- with Venom Demon 800 * f per hit, floor(10 * f) hits, Slow speed.
	At most once per second per victim (rule shared by the whole fruit, see _Shared).
	The coat itself deals no direct damage.

	The emitters and the body tint are a client effect driven by the replicated status,
	whose value is the fruit color string (Effects.Status.VenomBody).

	Legacy problems fixed here:
	- The handler had no level check at all (the 200 defense requirement was only in
	  the LocalScript).
	- Contact came from Touched connections on six limbs kept in script-level tables
	  shared with the haki listener; they were only undone by the toggle, never on
	  death, and the affinity they used was a script variable overwritten by whichever
	  Venom ability was used last (the Venom Demon one, or nil).
	- Contact is a small hitbox around the root checked four times a second.

	The key, a seal or a stun turns the coat off: the legacy client toggled it off the
	moment DF_Disabled was set, and the legacy stun set DF_Disabled.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local STATUS = "VenomBody"

local DAMAGE = 350
local DEMON_DAMAGE = 800
local HITS = 10
-- The legacy hit test was "a limb touched a part of the other character": the two
-- bodies have to overlap, which is about 4 studs between their roots (Hitbox adds the
-- 2.5 stud body of the target to this).
local HIT_RADIUS = 1.5
local TICK = 0.25

local PoisonCoat = Ability.extend()

function PoisonCoat:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(STATUS, self:GetColorString(), nil, true)

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end

		local demon = Shared.IsDemon(entity)
		for _, target in Hitbox.Sphere(entity.Root.Position, HIT_RADIUS, entity) do
			if demon then
				Shared.Poison(self, target, DEMON_DAMAGE, HITS, "Defense", "Slow")
			else
				Shared.Poison(self, target, DAMAGE, HITS, "Defense", "Normal")
			end
		end
		task.delay(TICK, tick)
	end
	task.delay(TICK, tick)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server
	-- 108-110, 169-174): 350 * affinity * (level / cap) per hit, Normal speed, but
	-- floor(10 * affinity) hits (no level term) and no one-second rule. While Venom
	-- Demon is on its own entry wins (it comes first in the legacy chain).
	BodyTouch.Set(entity, "Venom", {
		OnHit = function(target)
			local affinity = self:GetAffinity("Defense")
			Shared.Apply(
				self,
				target,
				DAMAGE * affinity * self:GetLevelScale("Defense"),
				math.floor(HITS * affinity),
				"Normal"
			)
		end,
	})
end

function PoisonCoat:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Venom", nil)
	-- Invalidates the pending tick of the run that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return PoisonCoat
