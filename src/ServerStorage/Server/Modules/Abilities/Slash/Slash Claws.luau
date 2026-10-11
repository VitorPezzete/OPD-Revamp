--!strict
--[[
	Slash fruit - Slash Claws (toggle + click).

	The key grows three claws on each hand (0.5 s between two presses). While they are
	out, every click throws a claw cut towards the aim point.

	With a = sword affinity and f = a * (sword level / cap):
	- claws stick out 0.5 + 0.5 * f studs (visual only);
	- cut damage 425 * f * (1 + BuffWeapons / 100), Special, dodgeable, tag "Slash";
	  armament haki doubles it and makes it Haki;
	- the cut is 11.44 wide, 19.44 tall and 7.98 deep, all times a; it flies at 50 * a
	  studs per second for 0.75 s from the right hand; 0.25 s between cuts.

	The click reaches the server as phase 3 of this ability, sent by the owner's
	SlashClaws status effect (which also plays the swing). Visuals: Effects.Status.SlashClaws
	(the claws) and Effects.OneShot.SlashBlade (the cut).

	Legacy problems fixed here:
	- The server decided on/off by looking for the claw part while the client kept its own
	  flag; a lost remote left the click binding and the claws disagreeing.
	- Retracting waited 0.5 s inside the remote handler and the claws stayed on a dead or
	  sealed character. Everything goes through OnInterrupt now.
	- The cut was an unanchored server part with a Touched connection.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local SlashShared = require(script.Parent._Shared)

local STATUS = "SlashClaws"
local EFFECT = "SlashBlade"

local CUT_DAMAGE = 425
local CUT_COOLDOWN = 0.25
local CUT_SPEED = 50
local CUT_LIFETIME = 0.75
-- Width, height, depth of the legacy cut part at affinity 1.
local CUT_SIZE = Vector3.new(11.4445, 19.4445, 7.9795)
local CLAW_BASE_LENGTH = 0.5
local CLAW_EXTRA_LENGTH = 0.5

local SlashClaws = Ability.extend()

SlashClaws.Debounce = 0.5

function SlashClaws:OnBegin()
	if self.Active then
		self:OnInterrupt()
		return
	end

	self.Active = true
	local factor = SlashShared.Factor(self)
	local context = self.Context
	-- "<fruit slot>|<ability slot>|<claw length>|<colors>": the owner's client needs the
	-- slots to address its clicks.
	self.Entity:SetStatus(
		STATUS,
		string.format(
			"%d|%d|%.2f|%s",
			context.FruitSlot,
			context.Definition.Slot,
			CLAW_BASE_LENGTH + CLAW_EXTRA_LENGTH * factor,
			self:GetColorString()
		),
		nil,
		true
	)
end

function SlashClaws:OnAction(input: Ability.AbilityInput)
	local now = os.clock()
	if now - (self.LastCut or 0) < CUT_COOLDOWN then
		return
	end
	self.LastCut = now

	local entity = self.Entity
	local factor, affinity = SlashShared.Factor(self)
	local multiplier, trait, haki = SlashShared.Haki(self)
	local origin = SlashShared.HandPosition(entity)
	local direction = SlashShared.Direction(entity, input.AimPosition)
	local speed = CUT_SPEED * affinity

	-- The two cut models alternate, as the two swing animations do on the client.
	self.SecondCut = not self.SecondCut

	SlashShared.Fly(self, {
		Origin = origin,
		Direction = direction,
		Speed = speed,
		Lifetime = CUT_LIFETIME,
		Size = CUT_SIZE * affinity,
		Damage = CUT_DAMAGE * factor * SlashShared.WeaponBuff(self) * multiplier,
		Trait = trait,
		Dodgeable = true,
	})

	self:PlayEffect(EFFECT, origin, {
		Kind = "Claw",
		Variant = if self.SecondCut then 2 else 1,
		Direction = direction,
		Speed = speed,
		Lifetime = CUT_LIFETIME,
		Scale = affinity,
		Haki = haki,
	})
end

function SlashClaws:OnInterrupt()
	self.Active = false
	-- Cuts still in flight vanish with the claws.
	self.Epoch = (self.Epoch or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return SlashClaws
