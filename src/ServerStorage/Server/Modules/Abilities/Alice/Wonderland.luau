--!strict
--[[
	Alice fruit - Wonderland: for a while, every player near the caster is pulled into
	Wonderland.

	Cost:      500 haki.
	Duration:  10 * defense affinity seconds.
	Radius:    haki level * 0.3 * defense affinity, following the caster.
	Every second, each player inside who is not already held is marked
	"AliceWonderland" (= caster's UserId) for 3 s and loses 1 haki to the caster. The
	mark is what Tea Party looks for to force a cup on them; "AliceInverted", set with
	it, shows the world in inverted colors on their screen (Effects.Status.AliceInverted).
	Someone who stays inside is marked again on the first tick after the 3 s run out.
	Marks still running when Wonderland ends run out on their own.
	Casting again while it runs only spends the haki, as in the legacy game (the first
	cast's timer ended every later one).

	KeepThroughStun: Wonderland keeps running when the caster is stunned (its own Weird
	tea included), as in the legacy game. A stunned caster cannot cast.

	Legacy problems fixed here:
	- The loop indexed the caster's character every second and errored forever after a
	  death; "already affected" entries of NPCs were never released.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local HAKI_COST = 500
local DURATION = 10
local RADIUS_PER_LEVEL = 0.3
local TICK = 1
local HOLD_TIME = 3
local HAKI_DRAIN = 1

local Wonderland = Ability.extend()

Wonderland.Debounce = 1
Wonderland.KeepThroughStun = true

function Wonderland:CanBegin(): boolean
	local entity: CharacterEntity = self.Entity
	return not entity:HasStatus(Shared.StunStatus) and Shared.GetHaki(entity) >= HAKI_COST
end

function Wonderland:OnBegin()
	local entity: CharacterEntity = self.Entity
	local services = self.Services
	Shared.AddHaki(services, entity, -HAKI_COST)
	if self.Active then
		return
	end

	local affinity = self:GetAffinity("Defense")
	local radius = self:GetLevel("Haki") * RADIUS_PER_LEVEL * affinity
	local duration = DURATION * affinity
	local userId = self.Player.UserId

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	entity:SetStatus(Shared.WonderlandActiveStatus, true)

	local endsAt = os.clock() + duration
	local function step()
		if self.Run ~= run then
			return
		end
		if os.clock() >= endsAt then
			-- Ran its course: players still marked keep their last 3 s.
			self.Active = false
			self.Run += 1
			entity:ClearStatus(Shared.WonderlandActiveStatus)
			return
		end

		for _, target in Hitbox.Sphere(entity.Root.Position, radius, entity) do
			if target.Player and not target:HasStatus(Shared.WonderlandStatus) then
				target:SetStatus(Shared.WonderlandStatus, userId, HOLD_TIME, true)
				target:SetStatus(Shared.InvertedStatus, true, HOLD_TIME, true)
				Shared.StealHaki(services, target, entity, HAKI_DRAIN)
			end
		end
		task.delay(TICK, step)
	end
	step()
end

function Wonderland:OnInterrupt()
	local wasActive = self.Active
	self.Active = false
	self.Run = (self.Run or 0) + 1

	local entity: CharacterEntity = self.Entity
	entity:ClearStatus(Shared.WonderlandActiveStatus)
	if not wasActive then
		return
	end

	-- Everyone still held by this caster is let go.
	local userId = self.Player.UserId
	for _, other in self.Services.Character:GetEntities() do
		if other:GetStatus(Shared.WonderlandStatus) == userId then
			other:ClearStatus(Shared.WonderlandStatus)
			other:ClearStatus(Shared.InvertedStatus)
		end
	end
end

return Wonderland
