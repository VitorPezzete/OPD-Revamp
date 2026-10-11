--!strict
--[[
	Blood fruit - passive: Blood is a logia. Melee and sword hits pass through the body
	(the Immunity damage modifier reads these two statuses; haki and special damage
	still land).

	A hit that passes through turns the body to blood for a second
	(Effects.OneShot.BloodLogia), at most once every 1.2 s and not while a body-painting
	ability of the other fruit is on (LogiaModule: Candy, Snow, Magma and Venom bodies,
	Gum 2nd Gear).

	AbilityService stops every passive of a character before starting them again, so
	clearing the shared immunity statuses here cannot strip another fruit's immunity.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local MELEE_STATUS = "MeleeImmunity"
local SWORD_STATUS = "SwordImmunity"
local BODY_STATUSES = { "CandyBody", "SnowBody", "MagmaBody", "VenomBody", "Gum2nd" }
local EFFECT = "BloodLogia"
local EFFECT_TIME = 1
local EFFECT_COOLDOWN = 1.2

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	local combatService = Knit.GetService("CombatService")
	local effectService = Knit.GetService("EffectService")

	entity:SetStatus(MELEE_STATUS, true)
	entity:SetStatus(SWORD_STATUS, true)

	local lastEffect = 0
	local connection = combatService.Blocked:Connect(function(context: CombatTypes.DamageContext)
		if context.Target ~= entity or context.CancelReason ~= "Immune" then
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
			Duration = EFFECT_TIME,
		})
	end)

	return function()
		connection:Disconnect()
		entity:ClearStatus(MELEE_STATUS)
		entity:ClearStatus(SWORD_STATUS)
	end
end
