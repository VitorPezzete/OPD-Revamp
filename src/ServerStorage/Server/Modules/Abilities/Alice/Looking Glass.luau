--!strict
--[[
	Alice fruit - Looking Glass: everyone around the caster is trapped behind the
	mirror for 5 seconds and cannot hurt any player meanwhile.

	Cost:    25 haki, 10 s cooldown.
	Area:    radius (50 + haki level * 0.15 * defense affinity) / 2 around the caster.
	Effect:  victims get the replicated status "AliceLookingGlass" = caster's UserId
	         for 5 s. DamageModifiers/AliceLookingGlass cancels every hit they land on
	         a player. Crew mates are cursed too, as in the legacy game.

	The curse is a timed debuff already delivered to other characters (like a DoT), so
	it runs out on its own; OnInterrupt has nothing of the caster's to undo.

	Legacy quirk kept: the Damage module tested `attacker.Alice.Effect2.UserId` on the
	*Player* object instead of the character, which raised an error and killed the damage
	function. What players lived with is therefore that a cursed attacker deals no damage
	to any player at all (NPCs are still hurt), not only to the caster; that is what the
	modifier reproduces.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local Shared = require(script.Parent._Shared)

type CharacterEntity = CharacterEntity.CharacterEntity

local STATUS = "AliceLookingGlass"
local PULSE_EFFECT = "AlicePulse"

local HAKI_COST = 25
local BASE_DIAMETER = 50
local DIAMETER_PER_LEVEL = 0.15
local DURATION = 5

local LookingGlass = Ability.extend()

LookingGlass.Debounce = 10

function LookingGlass:CanBegin(): boolean
	return Shared.GetHaki(self.Entity) >= HAKI_COST
end

function LookingGlass:OnBegin()
	local entity: CharacterEntity = self.Entity
	Shared.AddHaki(self.Services, entity, -HAKI_COST)

	local origin = entity.Root.Position
	local radius = (BASE_DIAMETER + self:GetLevel("Haki") * DIAMETER_PER_LEVEL * self:GetAffinity("Defense")) / 2
	self:PlayEffect(PULSE_EFFECT, origin, { Radius = radius })

	local userId = self.Player.UserId
	for _, target in Hitbox.Sphere(origin, radius, entity) do
		target:SetStatus(STATUS, userId, DURATION, true)
	end
end

return LookingGlass
