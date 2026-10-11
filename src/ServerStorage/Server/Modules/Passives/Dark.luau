--!strict
--[[
	Dark fruit passive: the user takes (3 - defense affinity) times the damage for as
	long as the fruit is owned (DamageModifiers.DarkVulnerability reads the status).

	Dark is not a logia for the immunity rules: the legacy list of fruits that let
	Melee / Sword hits through does not include it. LogiaModule still had a "turn to
	darkness" visual for it, which ran whenever a hit was negated by the user's OTHER
	fruit (a logia, Gum against melee, Chop against slashes): black smoke on the body for
	a second, at most once every 1.2 s and not while a body-painting ability is on. That
	is the client one-shot Effects.OneShot.DarkLogia. The legacy visual also tinted the
	body; here the tint is left to the other fruit's own effect, since two one-shots
	repainting the same limbs would each restore what the other one painted.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local STATUS = "DarkVulnerability"
local BASE = 3
-- Body-painting abilities ported so far (legacy: Candy, Magma, Venom, Snow bodies, Gum 2nd).
local BODY_STATUSES = { "CandyBody", "MagmaBody", "SnowBody" }
local SLASH_TAG = "Slash"
local EFFECT = "DarkLogia"
local EFFECT_COOLDOWN = 1.2

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	data: PlayerData.PlayerData,
	fruitSlot: number
): () -> ()
	local affinities = data.Data.Affinities
	local affinity = if fruitSlot == 1 then affinities.DF1.Defense else affinities.DF2.Defense
	entity:SetStatus(STATUS, BASE - affinity)

	-- Bare-handed hits of a Dark user are Special and scale with the fruit's melee
	-- affinity (read by AttackService).
	local meleeAffinity = if fruitSlot == 1 then affinities.DF1.Melee else affinities.DF2.Melee
	entity:SetStatus("MeleeTraitOverride", "Special")
	entity:SetStatus("MeleeDamageMultiplier", meleeAffinity)

	local combatService = Knit.GetService("CombatService")
	local effectService = Knit.GetService("EffectService")
	local lastEffect = 0

	local connection = combatService.Blocked:Connect(function(context: CombatTypes.DamageContext)
		if context.Target ~= entity or context.CancelReason ~= "Immune" then
			return
		end
		if context.Trait ~= "Melee" and context.Trait ~= "Sword" and context.Tag ~= SLASH_TAG then
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
		entity:ClearStatus(STATUS)
		entity:ClearStatus("MeleeTraitOverride")
		entity:ClearStatus("MeleeDamageMultiplier")
	end
end
