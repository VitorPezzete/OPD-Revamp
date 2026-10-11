--!strict
--[[
	Magma Gun
	- shot (config): a magma ball (Effects.OneShot.WeaponMagmaShot, the legacy "MagmaBu"
	  bullet) at 300 studs/s for 2.5 s, every 2 s. Sniper level * 1.314..., Special,
	  cannot be dodged, and it leaves a magma burn of 125 for 10 s;
	- special - Scatter: no level needed, cooldown 8 s. 0.3 s after the press 4 smaller
	  shots leave at 450 studs/s (2.5 s of flight), each up to 8 degrees off the aim on
	  every axis. Each deals the same damage as a shot, can be dodged, and burns for 175.
	Both kinds of ball were CanCollide false parts that only reacted to characters: walls
	do not stop them.

	The burn is the Magma fruit's ("MagmaBurn": same status and flame on the victim),
	ticking every 0.5 s like the fruit's. Owners of Rumble, Smelt, Hot or Plasma do not
	catch fire (the damage of the shot itself still lands).

	Legacy fired the scatter from an animation marker ("Hit") or when the track stopped,
	whichever came first; animations of this place may fail to load, so it is a fixed
	delay here. The legacy cooldown table was shared by every Magma Gun on the server
	but keyed by player, which AttackService does per player anyway.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Projectile = require(ServerStorage.Server.Modules.Projectile)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)

type CharacterEntity = CharacterEntity.CharacterEntity
type WeaponContext = WeaponTypes.WeaponContext

local BURN = "MagmaBurn"
local BURN_INTERVAL = 0.5
local BURN_SECONDS = 10
local SHOT_BURN = 125
local SCATTER_BURN = 175
local HEAT_PROOF: { [string]: boolean } = { Rumble = true, Smelt = true, Hot = true, Plasma = true }

local SCATTER_DELAY = 0.3
local SCATTER_SHOTS = 4
local SCATTER_SPREAD = 8
local SCATTER_SPEED = 450
local SCATTER_RANGE = 450 * 2.5
local SCATTER_EFFECT = "WeaponMagmaShot"

local MagmaGun: WeaponTypes.WeaponBehaviour = {}

local function burn(context: WeaponContext, target: CharacterEntity, amount: number)
	if target.Dead then
		return
	end
	local targetData = if target.Player then context.Services.Data:GetData(target.Player) else nil
	if targetData then
		local fruits = targetData.Data.DevilFruits
		if HEAT_PROOF[fruits.Slot1.Name] or HEAT_PROOF[fruits.Slot2.Name] then
			return
		end
	end

	context.Services.Status:ApplyDot(target, BURN, {
		Source = context.Entity,
		Damage = amount,
		Interval = BURN_INTERVAL,
		Ticks = BURN_SECONDS / BURN_INTERVAL,
		Trait = "Special",
	})
end

function MagmaGun.OnHit(context: WeaponContext, target: CharacterEntity, _dealt: number)
	burn(context, target, SHOT_BURN)
end

function MagmaGun.Special(context: WeaponContext): boolean?
	local entity = context.Entity
	local weapon = context.Weapon
	local damage = (weapon.Damage + (weapon.LevelScale or 1) * context.Level) * context.HakiMultiplier * context.PerkMultiplier
	local trait = if context.Haki then "Haki" else weapon.Trait
	local aim = context.Aim

	task.delay(SCATTER_DELAY, function()
		if not context:IsHolding() then
			return
		end

		local origin = entity.Root.Position
		if (aim - origin).Magnitude < 1e-3 then
			return
		end
		local base = CFrame.lookAt(origin, origin + Projectile.Lead(entity, origin, aim - origin, SCATTER_SPEED, SCATTER_RANGE))

		for _ = 1, SCATTER_SHOTS do
			local direction = (base * CFrame.Angles(
				math.rad(math.random(-SCATTER_SPREAD, SCATTER_SPREAD)),
				math.rad(math.random(-SCATTER_SPREAD, SCATTER_SPREAD)),
				math.rad(math.random(-SCATTER_SPREAD, SCATTER_SPREAD))
			)).LookVector

			context.Services.Effect:Play(SCATTER_EFFECT, origin, {
				Direction = direction,
				Speed = SCATTER_SPEED,
				Range = SCATTER_RANGE,
				Scale = 0.6,
				Caster = entity.Model,
			})
			Projectile.Fire({
				Origin = origin,
				Direction = direction,
				Speed = SCATTER_SPEED,
				MaxDistance = SCATTER_RANGE,
				Owner = entity,
				IgnoreWorld = true,
				OnHit = function(target: CharacterEntity)
					context.Services.Combat:Damage({
						Target = target,
						Attacker = entity,
						Amount = damage,
						Trait = trait,
						Style = "Weapon",
						Dodgeable = true,
					})
					burn(context, target, SCATTER_BURN)
				end,
			})
		end
	end)
	return true
end

return MagmaGun
