--!strict
--[[
	Venom fruit - Venom Demon (toggle + click, legacy `UsingVenomDemon`): a demon of
	poison grows around the user.

	From the moment it is toggled on, with a = defense affinity:
	- every hit the user takes is multiplied by 1 - 0.125 * a
	  (DamageModifiers.VenomDemon, fed by the VenomDemonGuard status);
	- the other Venom abilities are stronger (they read the VenomDemon status).
	The demon takes 3 s to form; once formed, with f = a * (defense level / cap):
	- touching its torso poisons: 800 * f per hit, floor(7 * f) hits, Slow; touching one
	  of its arms: 800 * f per hit, floor(5 * f) hits, Normal.
	From the toggle on (the legacy click did not wait for the demon to form), every click
	of the owner (phase 3 input from Effects.Status.VenomDemon -> OnAction, 0.5 s
	cooldown) claws a 10 stud cube 10 studs ahead: 500 flat "Special" damage, not
	dodgeable, and poison 800 * f per hit, floor(5 * f) hits, Slow.
	Toggling again, death, a seal or a stun removes it (the legacy demon went away as
	soon as DF_Disabled was set, which the legacy stun did).

	Legacy problems fixed here:
	- The 3 s build-up was a loop inside the remote handler and each joint of the demon
	  had its own Heartbeat connection that was never disconnected.
	- The affinity of the click was a script variable left by whichever Venom ability
	  was used last (nil before the first one: the handler errored).
	- The demon's parts, Touched connections and the DF_Disabled listener were server
	  instances that outlived a death.

	Contact. The legacy game used Touched on the `Hitbox` parts of the full demon
	(Fruits.Venom.Power6.FullDemon): one of 20 x 25 x 15 on the torso and one of
	10 x 10 x 20 on each arm; head and wings had none. The same three boxes are tested
	here four times a second, where the demon's joints put them relative to the user's
	root (the arms reach 19 studs ahead). The torso is tested first, and the fruit-wide
	rule of one application per victim per second decides between overlapping boxes.
	The arm boxes do not follow the swing animation.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

local STATUS = Shared.DEMON_STATUS
local GUARD_STATUS = "VenomDemonGuard"

local GUARD_PER_AFFINITY = 0.125
local BUILD_TIME = 3
local POISON_DAMAGE = 800
local TORSO_HITS = 7
local ARM_HITS = 5
-- Hits (times the affinity) of the poison a Gum punch carries while the demon is on.
local PUNCH_HITS = 10
-- Hitbox centres from the FullDemon joints: RootToRoot, then DemonRightArm / DemonLeftArm.
local TORSO_BOX = { Offset = CFrame.new(-0.15, 8, 1.39), Size = Vector3.new(20, 25, 15) }
local ARM_BOXES = {
	{ Offset = CFrame.new(9.96, 5.61, -9.12), Size = Vector3.new(10, 10, 20) },
	{ Offset = CFrame.new(-10.26, 5.61, -9.12), Size = Vector3.new(10, 10, 20) },
}
local TICK = 0.25
local CLAW_DAMAGE = 500
local CLAW_HITS = 5
local CLAW_SIZE = Vector3.new(10, 10, 10)
local CLAW_DISTANCE = 10
local CLAW_COOLDOWN = 0.5

local VenomDemon = Ability.extend()

function VenomDemon:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	-- "<fruit slot>;<ability slot>;<colors>": the owner's client needs the slots to
	-- address its clicks, everyone needs the colors to paint the demon.
	local context = self.Context
	entity:SetStatus(STATUS, `{context.FruitSlot};{context.Definition.Slot};{self:GetColorString()}`, nil, true)
	entity:SetStatus(GUARD_STATUS, GUARD_PER_AFFINITY * self:GetAffinity("Defense"))

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end
		local root = entity.Root.CFrame
		for _, target in Hitbox.Box(root * TORSO_BOX.Offset, TORSO_BOX.Size, entity) do
			Shared.Poison(self, target, POISON_DAMAGE, TORSO_HITS, "Defense", "Slow")
		end
		for _, arm in ARM_BOXES do
			for _, target in Hitbox.Box(root * arm.Offset, arm.Size, entity) do
				Shared.Poison(self, target, POISON_DAMAGE, ARM_HITS, "Defense", "Normal")
			end
		end
		task.delay(TICK, tick)
	end
	task.delay(BUILD_TIME, tick)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server
	-- 105-107, 175-180), from the toggle on: 800 * affinity * (level / cap) per hit, Slow,
	-- floor(10 * affinity) hits (no level term), no one-second rule.
	BodyTouch.Set(entity, "VenomDemon", {
		OnHit = function(target)
			local affinity = self:GetAffinity("Defense")
			Shared.Apply(
				self,
				target,
				POISON_DAMAGE * affinity * self:GetLevelScale("Defense"),
				math.floor(PUNCH_HITS * affinity),
				"Slow"
			)
		end,
	})
end

function VenomDemon:OnAction()
	local now = os.clock()
	if now - (self.LastClaw or 0) < CLAW_COOLDOWN then
		return
	end
	self.LastClaw = now

	for _, target in Hitbox.InFront(self.Entity, CLAW_SIZE, CLAW_DISTANCE) do
		Shared.Poison(self, target, POISON_DAMAGE, CLAW_HITS, "Defense", "Slow")
		self:Damage(target, CLAW_DAMAGE, "Special", nil, false)
	end
end

function VenomDemon:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "VenomDemon", nil)
	-- Invalidates the pending tick of the run that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
	self.Entity:ClearStatus(GUARD_STATUS)
end

return VenomDemon
