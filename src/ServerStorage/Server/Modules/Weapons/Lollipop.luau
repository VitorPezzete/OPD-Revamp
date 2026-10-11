--!strict
--[[
	Lollipop
	- every swing that lands has a 45% chance to stick the target in syrup: the Candy
	  fruit's "CandyTouched" debuff for 3 hits (CandyShared.Touch: 10% speed for 3.25 s,
	  Luck owners immune);
	- special: licks it. Heals 10000 health at once. Cooldown 19 s.

	The pink ring of the heal is Effects.OneShot.WeaponLollipopHeal.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local CandyShared = require(ServerStorage.Server.Modules.Abilities.Candy._Shared)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type WeaponContext = WeaponTypes.WeaponContext

local STICK_CHANCE = 0.45
local STICK_HITS = 3
local HEAL = 10000
local HEAL_EFFECT = "WeaponLollipopHeal"

local Lollipop: WeaponTypes.WeaponBehaviour = {}

function Lollipop.OnHit(context: WeaponContext, target: CharacterEntity.CharacterEntity, _dealt: number)
	if math.random() <= STICK_CHANCE then
		-- Touch only reads .Entity and .Services (Fruit, Status), which a context has.
		CandyShared.Touch(context, target, STICK_HITS)
	end
end

function Lollipop.Special(context: WeaponContext): boolean?
	local entity = context.Entity
	entity:Heal(HEAL)
	context.Services.Effect:Play(HEAL_EFFECT, entity.Root.Position, { Caster = entity.Model })
	return true
end

return Lollipop
