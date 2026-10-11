--!strict
--[[
	Light fruit - logia passive.

	While the fruit is owned the body lets Melee and Sword hits through (the Immunity
	damage modifier reads these two statuses). The legacy game (Logia.server.luau) set
	the two flags from the fruit names alone and never removed them for any reason other
	than losing the fruit: haki and special damage are simply other traits, and a sealed
	fruit kept its immunity. The cleanup is the only way out.

	Each negated hit also showed the body turning to light for a second (LogiaModule), at
	most once every 1.2 s and not while a body-painting ability is on. That is a client
	one-shot now (Effects.OneShot.LightLogia).

	The Damage, RewardModule, HealthV2 and WS_Script legacy modules have no Light branch.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local MELEE_STATUS = "MeleeImmunity"
local SWORD_STATUS = "SwordImmunity"
-- Body abilities of a second fruit that already paint the body (the legacy list).
local BODY_STATUSES = { "MagmaBody", "CandyBody", "SnowBody", "VenomBody", "Gum2nd" }
local EFFECT = "LightLogia"
local EFFECT_COOLDOWN = 1.2

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	entity:SetStatus(MELEE_STATUS, true)
	entity:SetStatus(SWORD_STATUS, true)

	local combatService = Knit.GetService("CombatService")
	local effectService = Knit.GetService("EffectService")
	local lastEffect = 0

	local connection = combatService.Blocked:Connect(function(context: CombatTypes.DamageContext)
		if context.Target ~= entity or context.CancelReason ~= "Immune" then
			return
		end
		if context.Trait ~= "Melee" and context.Trait ~= "Sword" then
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
		entity:ClearStatus(SWORD_STATUS)
	end
end
