--!strict
--[[
	Shirayuki - special: the first dance. Needs sword level 500. Cooldown 8 s.

	Timeline, from the press (the centre is where the user stood when pressing):
	  0.00 s  a white ring closes in on the user (visual);
	  1.75 s  everyone within 75 studs of the centre is frozen in ice: stunned 4 s;
	  1.75 to 3.25 s  slashes of light cut the frozen (visual);
	  5.05 s  the ice shatters: each frozen character takes 5 * (30 + sword level), with
	          the BuffWeapons perk, x2 and Haki with armament haki (as it was when the
	          key was pressed). Dodgeable, tagged "Skill".

	Frozen characters carry the replicated "WeaponShirayukiFrozen" status until the
	shatter (Effects.Status draws the ice and the slashes and breaks it on removal); the
	ring and the blast are Effects.OneShot.WeaponShirayuki.

	Legacy problems fixed: targets were found by walking every descendant of Workspace
	for Humanoids; walk speed was zeroed through an attribute that stayed forever when
	the caster left before the shatter (the stun here ends on its own).
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Hitbox = require(ServerStorage.Server.Modules.Hitbox)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type WeaponContext = WeaponTypes.WeaponContext

local FREEZE_DELAY = 1.75
local SHATTER_DELAY = 3.3
local RADIUS = 75
local STUN = 4
local BASE_DAMAGE = 30
local DAMAGE_MULTIPLIER = 5
local STATUS = "WeaponShirayukiFrozen"
local STUN_NAME = "WeaponShirayuki"
local EFFECT = "WeaponShirayuki"

local Shirayuki: WeaponTypes.WeaponBehaviour = {}

function Shirayuki.Special(context: WeaponContext): boolean?
	local entity = context.Entity
	local services = context.Services
	local center = entity.Root.Position
	local haki = context.Haki
	local damage = (BASE_DAMAGE + context.Level) * context.PerkMultiplier * context.HakiMultiplier * DAMAGE_MULTIPLIER

	services.Effect:Play(EFFECT, center, { Caster = entity.Model, Delay = FREEZE_DELAY, Radius = RADIUS })

	task.delay(FREEZE_DELAY, function()
		if entity.Dead then
			return
		end

		local frozen = Hitbox.Sphere(center, RADIUS, entity)
		for _, target in frozen do
			services.Status:ApplyStun(target, STUN, STUN_NAME)
			target:SetStatus(STATUS, true, SHATTER_DELAY, true)
		end

		task.delay(SHATTER_DELAY, function()
			for _, target in frozen do
				services.Combat:Damage({
					Target = target,
					Attacker = entity,
					Amount = damage,
					Trait = if haki then "Haki" else "Sword",
					Style = "Weapon",
					Dodgeable = true,
					Tag = "Skill",
				})
			end
		end)
	end)
	return true
end

return Shirayuki
