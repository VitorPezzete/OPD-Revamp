--!strict
--[[
	Plasma fruit - logia passive.

	While the fruit is owned the body lets Melee and Sword hits through (the Immunity
	damage modifier reads these two statuses). The legacy game (Logia.server) set the two
	flags when the character spawned or a fruit slot changed and never removed them for
	any other reason: haki and special damage are different traits, and a sealed fruit
	kept its immunity. So the cleanup (fruit or character gone) is the only way out.

	Each negated hit also turned the body to plasma for a second, with sparks flying off
	it (LogiaModule), at most once every 1.2 s and not while a body-painting ability is
	on. The moment comes from CombatService.Blocked; the replicated, timed "PlasmaLogia"
	status (value: fruit colors) drives Effects.Status.PlasmaLogia.

	With two logia fruits both passives set the same immunity statuses. AbilityService
	stops every passive before restarting the remaining ones, so the cleanup of one never
	strips the immunity the other still grants.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local MELEE_STATUS = "MeleeImmunity"
local SWORD_STATUS = "SwordImmunity"
local EFFECT_STATUS = "PlasmaLogia"
-- Body-painting abilities ported so far (legacy: Candy, Magma, Venom, Snow bodies, Gum 2nd).
local BODY_STATUSES = { "MagmaBody", "SnowBody" }

local EFFECT_SECONDS = 1
local EFFECT_COOLDOWN = 1.2

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	entity:SetStatus(MELEE_STATUS, true)
	entity:SetStatus(SWORD_STATUS, true)

	local lastEffect = 0
	local connection = Knit.GetService("CombatService").Blocked:Connect(function(context: CombatTypes.DamageContext)
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
		local colors = if fruitSlot == 1 then fruits.Slot1.Color else fruits.Slot2.Color
		entity:SetStatus(EFFECT_STATUS, colors, EFFECT_SECONDS, true)
	end)

	return function()
		connection:Disconnect()
		entity:ClearStatus(MELEE_STATUS)
		entity:ClearStatus(SWORD_STATUS)
		entity:ClearStatus(EFFECT_STATUS)
	end
end
