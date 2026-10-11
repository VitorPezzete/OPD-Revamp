--!strict
--[[
	Gum fruit - rubber body passive. The legacy Logia.server gave a Gum owner the Melee
	immunity of the logias (but not the Sword one): plain "Melee" hits bounce off for as
	long as the fruit is owned (the Immunity damage modifier reads the status). Haki and
	Special damage go through as usual. The legacy game never removed the flag for any
	reason other than losing the fruit, so the cleanup (fruit or character gone) is the
	only way out.

	Each negated hit also showed the body flushing for a second (LogiaModule), at most once
	every 1.2 s and not while a body-painting ability (2nd Gear included) is on. That is a
	client one-shot now (Effects.OneShot.GumLogia).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local MELEE_STATUS = "MeleeImmunity"
-- Body-painting abilities (legacy: Candy, Magma, Venom, Snow bodies, Gum 2nd).
local BODY_STATUSES = { "MagmaBody", "CandyBody", "SnowBody", "VenomBody", "Gum2nd" }
local EFFECT = "GumLogia"
local EFFECT_COOLDOWN = 1.2

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	entity:SetStatus(MELEE_STATUS, true)

	local combatService = Knit.GetService("CombatService")
	local effectService = Knit.GetService("EffectService")
	local lastEffect = 0

	local connection = combatService.Blocked:Connect(function(context: CombatTypes.DamageContext)
		if context.Target ~= entity or context.CancelReason ~= "Immune" or context.Trait ~= "Melee" then
			return
		end
		for _, status in BODY_STATUSES do
			if entity:HasStatus(status) then
				return
			end
		end

		local now = os.clock()
		if now - lastEffect < EFFECT_COOLDOWN then
			return
		end
		lastEffect = now

		local fruits = data.Data.DevilFruits
		effectService:Play(EFFECT, entity.Root.Position, {
			Caster = entity.Model,
			Colors = if fruitSlot == 1 then fruits.Slot1.Color else fruits.Slot2.Color,
		})
	end)

	return function()
		connection:Disconnect()
		entity:ClearStatus(MELEE_STATUS)
	end
end
