--!strict
--[[
	Slash fruit - Slash Frenzy: everything around the caster is cut.

	With d = defense affinity and f = sword affinity * (sword level / cap):
	- lasts 7.5 * d seconds. The caster can walk meanwhile (the legacy NoWalk line was
	  commented out; only the NoMovement flag was set, which refused dashes, Shave and
	  flight take-offs);
	- area: a sphere of radius 100 * d around the caster, wherever the caster is at each
	  round. While the caster also has an Ope Room open and stands inside it, the area
	  is the Room instead;
	- every 0.25 s each character in the area is cut twice (0.1 s apart), each cut
	  75 * f * (1 + BuffWeapons / 100), Special, not dodgeable, tag "Slash"; armament haki
	  (checked per cut) doubles it and makes it Haki;
	- cooldown 120 s, shortened by 10 * d seconds for every player killed since the last
	  use. It also runs from the moment the character spawns (or the fruit is eaten).

	The cooldown is `self.LastUsed` on this object, which survives stuns and seals. The
	spawn time and the kill count come from Passives.Slash through two entity statuses:
	the passive exists before the first press, this object does not.

	Visual: Effects.Status.SlashFrenzy, which draws the slashes flying through the area.
	Stuns do not stop the frenzy (KeepThroughStun), as in the legacy game; death, seal and
	losing the fruit do.

	Legacy problems fixed / simplified:
	- The server only enforced 5 s between uses; the 120 s cooldown was the client's.
	- The NoMovement flag stayed set forever when the script died mid-loop.
	- Cuts were parts thrown at each victim at 2000 * affinity studs per second from a
	  random point of the area: an almost instant hit, applied directly here. The one or
	  two extra slashes thrown at random points each tick could also hit by chance; they
	  are only drawn now.

	NoMovement and the flight disabler: the replicated "SlashFrenzy" status is listed in
	MovementConfig.NoMovementStatuses / BlockingStatuses (no Dash, no Shave, no take-off of
	the flights that checked the flag), and every round raises the character's flight lock
	for 3 s like the legacy `FDPModule:AddFDP(3)` (DF Slash.server 589): flights land when
	the frenzy starts and stay grounded until 3 s after its last round.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local SlashShared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "SlashFrenzy"
-- Shared state table of the Ope fruit (Abilities/Ope/OpeRoom), read only.
local OPE_STATE_STATUS = "OpeState"

local COOLDOWN = 120
local KILL_REFUND = 10
local DURATION = 7.5
local RADIUS = 100
local TICK = 0.25
local SECOND_CUT_DELAY = 0.1
local CUT_DAMAGE = 75

local SlashFrenzy = Ability.extend()

SlashFrenzy.KeepThroughStun = true

-- Seconds before the next use is allowed (<= 0 when ready).
function SlashFrenzy:GetCooldownLeft(): number
	local entity = self.Entity
	local lastUsed = self.LastUsed or entity:GetStatus(SlashShared.FrenzyBornStatus)
	if type(lastUsed) ~= "number" then
		return 0
	end

	local kills = entity:GetStatus(SlashShared.FrenzyKillsStatus)
	local refund = (if type(kills) == "number" then kills else 0) * KILL_REFUND * self:GetAffinity("Defense")
	return COOLDOWN - (os.clock() - lastUsed) - refund
end

function SlashFrenzy:CanBegin(): boolean
	return not self.Active and self:GetCooldownLeft() <= 0
end

-- Center and radius of the caster's open Ope Room when the caster stands inside it.
local function getRoom(entity: CharacterEntity): (Vector3?, number?)
	local state = entity:GetStatus(OPE_STATE_STATUS)
	if type(state) ~= "table" or state.Open ~= true then
		return nil, nil
	end

	local center, final, rate, openedAt = state.Center, state.FinalRadius, state.GrowRate, state.OpenedAt
	if typeof(center) ~= "Vector3" or type(final) ~= "number" or type(rate) ~= "number" or type(openedAt) ~= "number" then
		return nil, nil
	end

	local radius = math.min(final, (os.clock() - openedAt) * rate)
	if (entity.Root.Position - center).Magnitude < radius then
		return center, radius
	end
	return nil, nil
end

function SlashFrenzy:OnBegin()
	local entity = self.Entity
	self.LastUsed = os.clock()
	self:StartCooldown(COOLDOWN)
	entity:SetStatus(SlashShared.FrenzyKillsStatus, 0)

	local defense = self:GetAffinity("Defense")
	local factor, swordAffinity = SlashShared.Factor(self)
	local damage = CUT_DAMAGE * factor * SlashShared.WeaponBuff(self)
	local duration = DURATION * defense

	local colors = self:GetColorString()
	local lastValue: string? = nil

	-- Where the cuts land this round. The replicated status tells the clients the same:
	-- "<radius>|F|||<sword affinity>|<colors>" while the area follows the caster,
	-- "<radius>|<x>|<y>|<z>|<sword affinity>|<colors>" while it is the Room. It is only
	-- written again when it changes, so the effect is not restarted every round.
	local function area(): (Vector3, number)
		local center: Vector3, radius: number = entity.Root.Position, RADIUS * defense
		local value = string.format("%.1f|F|||%.2f|%s", radius, swordAffinity, colors)
		local roomCenter, roomRadius = getRoom(entity)
		if roomCenter and roomRadius then
			center, radius = roomCenter, roomRadius
			value = string.format("%.1f|%.1f|%.1f|%.1f|%.2f|%s", radius, center.X, center.Y, center.Z, swordAffinity, colors)
		end
		if value ~= lastValue then
			lastValue = value
			entity:SetStatus(STATUS, value, nil, true)
		end
		return center, radius
	end

	self.Active = true
	self.Run = (self.Run or 0) + 1
	local run = self.Run
	local endsAt = os.clock() + duration
	area()

	local function cut(target: CharacterEntity)
		if self.Run ~= run then
			return
		end
		local multiplier, trait = SlashShared.Haki(self)
		self:Damage(target, damage * multiplier, trait, SlashShared.Tag, false)
	end

	-- Bounded: at most duration / TICK rounds (60 at the highest affinity).
	local function tick()
		if self.Run ~= run then
			return
		end
		if os.clock() >= endsAt then
			self:OnInterrupt()
			return
		end

		local center, radius = area()
		self.Services.Ability:RaiseFlightLock(entity)
		for _, target in Hitbox.Sphere(center, radius, entity) do
			cut(target)
			task.delay(SECOND_CUT_DELAY, cut, target)
		end
		task.delay(TICK, tick)
	end
	task.delay(TICK, tick)
end

function SlashFrenzy:OnInterrupt()
	-- The cooldown (self.LastUsed) is deliberately kept.
	self.Active = false
	self.Run = (self.Run or 0) + 1
	self.Entity:ClearStatus(STATUS)
end

return SlashFrenzy
