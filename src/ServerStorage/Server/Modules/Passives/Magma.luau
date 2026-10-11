--!strict
--[[
	Magma fruit - logia passive.

	While the fruit is owned the body lets Melee and Sword hits through (the Immunity
	damage modifier reads these two statuses). The legacy game set the two flags when the
	character spawned or a fruit value changed and never took them away for any other
	reason: haki and special damage simply are different traits, and a sealed fruit kept
	its immunity. Nothing else is needed for "when it is lost": the cleanup runs when the
	fruit or the character goes away.

	Each negated hit also showed the body turning to magma for a second (LogiaModule),
	at most once every 1.2 s and not while a body ability (Magma Body, or the Candy /
	Snow / Venom body or 2nd Gear of a second fruit) already paints the body. That is a
	client one-shot now (Effects.OneShot.MagmaLogia). The legacy burn script showed it
	as well for every tick of a magma burn the owner shrugged off (tag "MagmaBurn",
	cancelled by DamageModifiers.MagmaBurnImmunity).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local MELEE_STATUS = "MeleeImmunity"
local SWORD_STATUS = "SwordImmunity"
local BODY_STATUSES = { "MagmaBody", "CandyBody", "SnowBody", "VenomBody", "Gum2nd" }
local BURN_TAG = "MagmaBurn"
local EFFECT = "MagmaLogia"
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
		if context.Trait ~= "Melee" and context.Trait ~= "Sword" and context.Tag ~= BURN_TAG then
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
