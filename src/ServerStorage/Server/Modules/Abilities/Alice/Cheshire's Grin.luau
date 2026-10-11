--!strict
--[[
	Alice fruit - Cheshire's Grin: the cat appears over everyone around the caster,
	holds them in place, and blows up three seconds later.

	With a = defense affinity and L = haki level:
	Cost:     200 haki, 15 s cooldown.
	Area:     radius (50 + L * 0.15 * a) / 2 around the caster.
	Victims:  stunned 1.5 * a seconds and marked "AliceGrin" for 3 s (the cat over the
	          head); players also get "AliceInverted" for 3 s (on their own screen, the
	          world in inverted colors). Crew mates are caught too, as in the legacy game.
	Blast:    3 s after the cast, one per victim that is still alive, centred on it,
	          radius (L * 0.06 * a) / 2. Everyone in a blast takes
	              caster's health at cast * a^2 * (L / 500) * 0.075
	          ("Special", not dodgeable); 0.125 instead of 0.075 when the caster's last
	          tea was Max or Haki. Standing in several blasts hurts several times.

	KeepThroughStun: the blast still goes off when the caster is stunned meanwhile, as in
	the legacy game. A stunned caster cannot cast.

	Legacy problems fixed here:
	- The blast was centred on whichever limb the area query happened to return first
	  and errored when the victim had been destroyed in the meantime.
	- The server created the query sphere, the cat and the explosion parts.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "AliceGrin"
local PULSE_EFFECT = "AlicePulse"
local BURST_EFFECT = "AliceGrinBurst"

local HAKI_COST = 200
local BASE_DIAMETER = 50
local DIAMETER_PER_LEVEL = 0.15
local BLAST_DIAMETER_PER_LEVEL = 0.06
local STUN = 1.5
local FUSE = 3
local DAMAGE_RATIO = 0.075
local STRONG_TEA_RATIO = 0.125
-- The blast is drawn above the victim's head, where the legacy explosion part was.
local BURST_HEIGHT = 6.5

local Grin = Ability.extend()

Grin.Debounce = 15
Grin.KeepThroughStun = true

function Grin:CanBegin(): boolean
	local entity: CharacterEntity = self.Entity
	return not entity:HasStatus(Shared.StunStatus) and Shared.GetHaki(entity) >= HAKI_COST
end

local function detonate(self: any, victims: { CharacterEntity }, damage: number, blastRadius: number, epoch: number)
	if self.Epoch ~= epoch then
		return
	end
	self.Victims = nil

	local entity: CharacterEntity = self.Entity
	for _, victim in victims do
		if victim.Dead or not victim.Spawned or victim.Model.Parent == nil then
			continue
		end

		local center = victim.Root.Position
		self:PlayEffect(BURST_EFFECT, center + Vector3.new(0, BURST_HEIGHT, 0), { Size = blastRadius * 2 })
		for _, target in Hitbox.Sphere(center, blastRadius, entity) do
			self:Damage(target, damage, "Special", STATUS, false)
		end
	end
end

function Grin:OnBegin()
	local entity: CharacterEntity = self.Entity
	local services = self.Services
	Shared.AddHaki(services, entity, -HAKI_COST)

	local affinity = self:GetAffinity("Defense")
	local level = self:GetLevel("Haki")
	local origin = entity.Root.Position
	local radius = (BASE_DIAMETER + level * DIAMETER_PER_LEVEL * affinity) / 2
	local blastRadius = level * BLAST_DIAMETER_PER_LEVEL * affinity / 2

	local tea = entity:GetStatus(Shared.TeaStatus)
	local ratio = if tea == "Max" or tea == "Haki" then STRONG_TEA_RATIO else DAMAGE_RATIO
	local damage = entity.Health * affinity * affinity * (level / Shared.HakiLevelDivisor) * ratio

	self:PlayEffect(PULSE_EFFECT, origin, { Radius = radius })

	local victims: { CharacterEntity } = {}
	for _, target in Hitbox.Sphere(origin, radius, entity) do
		table.insert(victims, target)
		target:SetStatus(STATUS, true, FUSE, true)
		if target.Player then
			target:SetStatus(Shared.InvertedStatus, true, FUSE, true)
		end
		services.Status:ApplyStun(target, STUN * affinity)
	end
	if #victims == 0 then
		return
	end

	self.Epoch = (self.Epoch or 0) + 1
	self.Victims = victims
	task.delay(FUSE, detonate, self, victims, damage, blastRadius, self.Epoch)
end

function Grin:OnInterrupt()
	-- Death, seal or fruit loss: the pending blast is called off and the cats vanish with it.
	self.Epoch = (self.Epoch or 0) + 1
	local victims: { CharacterEntity }? = self.Victims
	if victims then
		self.Victims = nil
		for _, victim in victims do
			victim:ClearStatus(STATUS)
		end
	end
end

return Grin
