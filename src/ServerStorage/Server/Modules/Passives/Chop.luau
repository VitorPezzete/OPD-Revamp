--!strict
--[[
	Chop fruit - passive: a body that is already in pieces cannot be cut.

	The legacy Logia script gave a Chop user the SwordImmunity flag (not the melee one):
	every plain "Sword" hit passes through, through the Immunity damage modifier that reads
	this status. Haki and special damage still land. Hits tagged "Slash" are negated
	whatever their trait by DamageModifiers.ChopSlashImmunity.

	A negated hit makes the body fall apart and snap back (LogiaModule played
	Powers.Chop.Logia.Animation at four times its speed), at most once every 1.2 s. That
	is the ChopLogia one-shot now, played by the owner's client.

	AbilityService stops every passive of a character before starting them again, so
	clearing the shared immunity status here cannot strip another fruit's immunity.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local SWORD_STATUS = "SwordImmunity"
-- LogiaModule showed nothing while one of these body abilities was on.
local BODY_STATUSES = { "CandyBody", "SnowBody", "MagmaBody", "VenomBody", "Gum2nd" }
local EFFECT = "ChopLogia"
local EFFECT_COOLDOWN = 1.2

return function(
	entity: CharacterEntity.CharacterEntity,
	_player: Player,
	_data: PlayerData.PlayerData,
	_fruitSlot: number
): () -> ()
	local combatService = Knit.GetService("CombatService")
	local effectService = Knit.GetService("EffectService")

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

		effectService:Play(EFFECT, entity.Root.Position, { Caster = entity.Model })
	end)

	return function()
		connection:Disconnect()
		entity:ClearStatus(SWORD_STATUS)
	end
end
