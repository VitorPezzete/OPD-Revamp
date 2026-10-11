--!strict
--[[
	Dough fruit - logia passive ("Dough" is in the logia list of the source's Logia script).

	While the fruit is owned the body lets Melee and Sword hits through (the Immunity
	damage modifier reads these two statuses). As for the other logias, the flags only go
	with the fruit or the character: a sealed fruit keeps its immunity.

	Each negated hit also showed the body turning to mochi for a second (LogiaModule), at
	most once every 1.2 s. That is a client one-shot now (Effects.OneShot.DoughLogia).
	The source's Damage module has a Dough branch (haki bar cost, defense exp) that is
	commented out: nothing of it is reproduced.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local MELEE_STATUS = "MeleeImmunity"
local SWORD_STATUS = "SwordImmunity"
-- Body-painting abilities (LogiaModule: Candy, Snow, Magma and Venom bodies, Gum 2nd Gear):
-- the flash would fight them over the body color.
local BODY_STATUSES = { "CandyBody", "SnowBody", "MagmaBody", "VenomBody", "Gum2nd" }
local EFFECT = "DoughLogia"
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
