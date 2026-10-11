--!strict
--[[
	Candy fruit - Spike Body (toggle): the body hardens into spiked candy.

	With k = defense affinity * (defense level / cap), while it is on:
	- every hit taken is reduced by 12.5 % * k (DamageModifiers.CandyBody reads the
	  fraction stored in the CandyBodyGuard status when the body is turned on);
	- whoever touches the body, at most once per second per victim, takes 50 * k "Sword"
	  damage (not dodgeable; doubled and "Haki" with armament haki) and is stuck in syrup:
	  CandyTouched for 3 s (CandyShared.Touch).

	The candy body is a client effect driven by the replicated CandyBody status, whose
	value is the fruit color string (Effects.Status.CandyBody). While it is on, the logia
	"hit passes through" visual is skipped (Passives.Candy), as in the legacy game.

	Legacy problems fixed here:
	- Damage came from Touched connections on six body parts with a cooldown per TOUCHING
	  part kept in a table that was never cleared; the cleanup loop then removed the
	  connections from the table by the wrong key. It is one small hitbox checked four
	  times a second while the body is on, one hit per second per victim.
	- The server rewrote Body Colors and restored them from the saved skin when turned
	  off, and nothing was restored on death. Nothing is changed on the server now.

	The tick is not capped in time (the legacy toggle was not either); it stops as soon
	as the ability is toggled off or interrupted.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local BodyTouch = require(ServerStorage.Server.Modules.BodyTouch)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local CandyShared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local GUARD = 0.125
local CONTACT_DAMAGE = 50
local TOUCH_HITS = 3
-- The legacy hit test was "a body part touched something": body contact range.
local HIT_RADIUS = 3.5
local HIT_COOLDOWN = 1
local TICK = 0.25
-- Armament haki on the damage a Gum punch carries (legacy `ExtraDamage *= 2`).
local PUNCH_HAKI_MULTIPLIER = 2

local SpikeBody = Ability.extend()

function SpikeBody:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	local entity = self.Entity
	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run

	entity:SetStatus(CandyShared.GuardStatus, GUARD * self:GetAffinity("Defense") * self:GetLevelScale("Defense"))
	entity:SetStatus(CandyShared.BodyStatus, self:GetColorString(), nil, true)

	local lastHit: { [CharacterEntity]: number } = setmetatable({}, { __mode = "k" }) :: any

	local function tick()
		if self.Run ~= run or not self.Active then
			return
		end

		local now = os.clock()
		local multiplier, haki = CandyShared.Haki(self)
		local damage = CONTACT_DAMAGE * self:GetAffinity("Defense") * self:GetLevelScale("Defense") * multiplier
		for _, target in Hitbox.Sphere(entity.Root.Position, HIT_RADIUS, entity) do
			if now - (lastHit[target] or 0) >= HIT_COOLDOWN then
				lastHit[target] = now
				self:Damage(target, damage, if haki then "Haki" else "Sword", nil, false)
				CandyShared.Touch(self, target, TOUCH_HITS)
			end
		end
		task.delay(TICK, tick)
	end
	task.delay(TICK, tick)

	-- Through a Gum punch of the same character (Modules.BodyTouch, DF Gum.server 89-92,
	-- 118-121, 155-159): the same syrup and the same damage as a contact, except that
	-- the damage is dodgeable like the punch that carries it.
	BodyTouch.Set(entity, "Candy", {
		OnHit = function(target, punch)
			CandyShared.Touch(self, target, TOUCH_HITS)
			local damage = CONTACT_DAMAGE * self:GetAffinity("Defense") * self:GetLevelScale("Defense")
			if punch.Haki then
				punch.Ability:Damage(target, damage * PUNCH_HAKI_MULTIPLIER, "Haki", nil, true)
			else
				punch.Ability:Damage(target, damage, "Sword", nil, true)
			end
		end,
	})
end

function SpikeBody:OnInterrupt()
	self.Active = false
	BodyTouch.Set(self.Entity, "Candy", nil)
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(CandyShared.GuardStatus)
	self.Entity:ClearStatus(CandyShared.BodyStatus)
end

return SpikeBody
