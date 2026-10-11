--!strict
--[[
	Roger - the thrown slash (config) catches fire in the hands of a Flare user: orange,
	flaming, and it leaves the Flare burn on whoever it cuts.

	Legacy: BurnOverTime with DoT 100 for 5 s. The burn ticks every 0.5 s like every
	other port of that control script, so 10 ticks of 100 ("FlareBurn", same status and
	visual as the fruit's own burn).
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local WeaponTypes = require(ServerStorage.Server.Types.WeaponTypes)
local WeaponShared = require(script.Parent._Shared)

type WeaponContext = WeaponTypes.WeaponContext

local FRUIT = "Flare"
local BURN = "FlareBurn"
local BURN_DAMAGE = 100
local BURN_INTERVAL = 0.5
local BURN_TICKS = 10

local Roger: WeaponTypes.WeaponBehaviour = {}

function Roger.SlashParams(context: WeaponContext): { [string]: any }?
	return if WeaponShared.HasFruit(context.Data, FRUIT) then { Flare = true } else nil
end

function Roger.OnSlashHit(context: WeaponContext, target: CharacterEntity.CharacterEntity)
	if target.Dead or not WeaponShared.HasFruit(context.Data, FRUIT) then
		return
	end
	context.Services.Status:ApplyDot(target, BURN, {
		Source = context.Entity,
		Damage = BURN_DAMAGE,
		Interval = BURN_INTERVAL,
		Ticks = BURN_TICKS,
		Trait = "Special",
	})
end

return Roger
