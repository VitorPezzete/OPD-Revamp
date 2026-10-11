--!strict
--[[
	Dough fruit - Mochi Gatling: while the key is held, mochi rings keep opening in the air
	around the aim point and each fires an arm at it.

	With f = Shared.Factor (melee), read once at the press:
	- every 0.125 s a ring opens somewhere above the current aim point (the place is the
	  client's own random, as in the source) and, 0.525 s later, everyone within 10 * f
	  studs of that aim point is hit: 5000 * f Haki damage with armament haki (read when
	  the ring opens), otherwise 2500 * f Melee; dodgeable. No knockback.
	- the user is free to move. The stream ends on release, when the user sits, dies or
	  is sealed (the source client's property checker), and then cools down for 1 s.

	Who drives it. The source server asked the client for its mouse position with
	InvokeClient before every ring (a hung client stalled the loop, and the answer was not
	checked). The stream is a server tick now; Effects.Status.DoughGatling streams the aim
	as the ability's secondary input (OnAction), validated like any aim point.

	Status DoughGatling (replicated): "<fruit slot>|<ability slot>".

	Source oddity not reproduced: the list of characters already hit was built as
	`{character}` instead of `{[character] = true}`, so the user's own character was not
	excluded from its own punches. CombatService refuses self-damage anyway.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)
local Shared = require(script.Parent._Shared)

local NAME = "Mochi Gatling"
local SKILL = "Melee"
local STATUS = "DoughGatling"
local EFFECT = "DoughGatling"
local DAMAGE_TAG = "DoughGatling"

local COOLDOWN = 1
local INTERVAL = 0.125
local HIT_DELAY = 0.525
local HIT_RADIUS = 10
local MAX_DAMAGE = 5000

local MochiGatling = Ability.extend()
-- The source dealt this damage without a style: ResistAbilities does not apply.
MochiGatling.DamageStyle = "Plain"

function MochiGatling:CanBegin(): boolean
	local entity = self.Entity
	return not self.Active
		and os.clock() >= (self.ReadyAt or 0)
		and not Shared.IsUsing(entity)
		and not entity.Humanoid.Sit
end

function MochiGatling:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local factor = Shared.Factor(self, SKILL)

	self.Active = true
	self.Aim = input.AimPosition
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	Shared.SetUsing(entity, NAME)
	entity:SetStatus(STATUS, `{self.Context.FruitSlot}|{self.Context.Definition.Slot}`, nil, true)

	local function fire()
		if self.Run ~= run or not self.Active or entity.Dead then
			return
		end
		if entity.Humanoid.Sit then
			self:OnInterrupt()
			return
		end

		local aim: Vector3 = self.Aim
		local haki = Shared.Haki(self)
		self:PlayEffect(EFFECT, aim, { Factor = factor, Haki = haki })

		local damage = if haki then MAX_DAMAGE * factor else MAX_DAMAGE / 2 * factor
		local trait: CombatTypes.DamageTrait = if haki then "Haki" else "Melee"
		task.delay(HIT_DELAY, function()
			if entity.Dead then
				return
			end
			for _, target in Hitbox.Sphere(aim, HIT_RADIUS * factor, entity) do
				self:Damage(target, damage, trait, DAMAGE_TAG, true)
			end
		end)

		task.delay(INTERVAL, fire)
	end
	fire()
end

-- Aim update from the owner's client while the key is held.
function MochiGatling:OnAction(input: Ability.AbilityInput)
	self.Aim = input.AimPosition
end

function MochiGatling:OnEnd()
	if self.Active then
		self:OnInterrupt()
	end
end

function MochiGatling:OnInterrupt()
	if not self.Active then
		return
	end
	self.Active = false
	-- Invalidates the pending ring of the stream that just ended.
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
	Shared.ClearUsing(self.Entity, NAME)
	self.ReadyAt = os.clock() + COOLDOWN
	self:StartCooldown(COOLDOWN)
end

return MochiGatling
