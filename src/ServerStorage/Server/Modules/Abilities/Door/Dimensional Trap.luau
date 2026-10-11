--!strict
--[[
	Door fruit - Dimensional Trap: doors close around every enemy near the aimed point and
	hold them in place.

	DESIGNED, NOT PORTED (see Door Strike: the legacy Door fruit had no server logic and
	no assets). The legacy client sent the mouse position on key PRESS (the other three
	fire on release); the gate is Defense 400. Placeholder numbers:

		range:    120 studs (a further aim point is shortened to it)
		area:     vertical cylinder, radius 10, 8 studs up and down from the aimed point
		effect:   stun (rooted, abilities interrupted) for 2 * defense affinity seconds
		          (2-4 s). No damage. Team mates are not trapped.
		cooldown: 15 s
		The trap opens early if the caster dies, is stunned / sealed or loses the fruit.

	Victims carry the replicated "DoorTrapped" status (value: the caster's color string),
	which draws the doors around them (Effects.Status.DoorTrapped).
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "DoorTrapped"

local RANGE = 120
local RADIUS = 10
local HALF_HEIGHT = 8
local SECONDS_PER_AFFINITY = 2

local DimensionalTrap = Ability.extend()

DimensionalTrap.Debounce = 15

function DimensionalTrap:OnBegin(input: Ability.AbilityInput)
	local entity = self.Entity
	local origin = entity.Root.Position

	local offset = input.AimPosition - origin
	if offset.Magnitude > RANGE then
		offset = offset.Unit * RANGE
	end
	local center = origin + offset

	-- A second cast replaces the first trap.
	self:OnInterrupt()
	local run = self.Run

	local duration = SECONDS_PER_AFFINITY * self:GetAffinity("Defense")
	local colors = self:GetColorString()
	local trapped: { CharacterEntity } = {}

	for _, target in Hitbox.Cylinder(center, RADIUS, HALF_HEIGHT, entity) do
		if entity.Team ~= "" and entity.Team == target.Team then
			continue
		end
		self.Services.Status:ApplyStun(target, duration, STATUS)
		target:SetStatus(STATUS, colors, duration, true)
		table.insert(trapped, target)
	end

	if #trapped == 0 then
		return
	end

	self.Active = true
	self.Trapped = trapped
	task.delay(duration, function()
		-- The stun and the status have expired on their own; only forget the victims.
		if self.Run == run then
			self.Active = false
			self.Trapped = nil
		end
	end)
end

function DimensionalTrap:OnInterrupt()
	self.Active = false
	self.Run = (self.Run or 0) + 1

	local trapped: { CharacterEntity }? = self.Trapped
	self.Trapped = nil
	if trapped then
		for _, target in trapped do
			self.Services.Status:Clear(target, STATUS)
			target:ClearStatus(STATUS)
		end
	end
end

return DimensionalTrap
