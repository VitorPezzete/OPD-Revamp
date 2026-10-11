--!strict
--[[
	Alice fruit - state and helpers shared by its six abilities. Not an ability: the
	loader only looks modules up by ability name, so this one is never instantiated.

	Sibling abilities cannot see each other's objects, so everything the legacy script
	kept in script-level variables (ActiveTea, CardsCharges, WonderLand, WonderPlrs) is
	an entity status:

		AliceTea               caster   last tea drunk ("Haki", "Health", "Max", ...)
		AliceCardCharges       caster   Cards of Fate throws that skip the cooldown
		AliceTeaMax            anyone   +20% max health while set (timed)
		AliceWonderlandActive  caster   Wonderland is running
		AliceWonderland        victim   UserId of the Alice whose Wonderland holds them
		AliceInverted          victim   the world is shown in inverted colors (legacy
		                                "Effect1": Cheshire's Grin and Wonderland)

	Haki bar: every Alice ability costs haki and several steal it. The cost is checked
	against the replicated "HakiBar" attribute (written only by the server) and spent
	through HakiService:AddBar. A steal takes what the victim has, up to the amount, and
	gives the caster the whole amount, as the legacy `victim -= n; caster += n` did with
	a victim's bar that stopped at zero.

	Stuns: the legacy game refused every Alice key while its user was stunned
	(DF_Disabled) but never cancelled what was already running. Abilities with something
	in progress set KeepThroughStun and test StunStatus in CanBegin.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)

type CharacterEntity = CharacterEntity.CharacterEntity

local Shared = {}

Shared.TeaStatus = "AliceTea"
Shared.CardChargesStatus = "AliceCardCharges"
Shared.TeaMaxStatus = "AliceTeaMax"
Shared.WonderlandActiveStatus = "AliceWonderlandActive"
Shared.WonderlandStatus = "AliceWonderland"
Shared.InvertedStatus = "AliceInverted"

Shared.StunStatus = "Stunned"

-- Legacy formulas divide the haki level by 500 (the old cap), not by the current cap.
Shared.HakiLevelDivisor = 500

local TEA_MAX_MODIFIER = "AliceTeaMax"
local TEA_MAX_MULTIPLIER = 1.2
local HAKI_ATTRIBUTE = "HakiBar"

function Shared.GetHaki(entity: CharacterEntity): number
	local bar = entity.Model:GetAttribute(HAKI_ATTRIBUTE)
	return if type(bar) == "number" then bar else 0
end

-- Adds (or, with a negative amount, spends) haki. False when a spend is more than is left.
function Shared.AddHaki(services: any, entity: CharacterEntity, amount: number): boolean
	return services.Haki:AddBar(entity, amount)
end

-- Moves haki from a player victim to the caster. Victims with an empty bar give nothing.
function Shared.StealHaki(services: any, victim: CharacterEntity, caster: CharacterEntity, amount: number)
	if not victim.Player or amount <= 0 then
		return
	end

	local bar: number = services.Haki:GetBar(victim)
	if bar <= 0 then
		return
	end
	services.Haki:AddBar(victim, -math.min(amount, bar))
	services.Haki:AddBar(caster, amount)
end

-- Same crew-war team. Only the auto-target of Cards of Fate uses it: the legacy stuns
-- and curses never looked at teams (damage refuses team mates in CombatService).
function Shared.IsEnemy(caster: CharacterEntity, target: CharacterEntity): boolean
	return not (caster.Team ~= "" and caster.Team == target.Team)
end

-- The "Max" tea: +20% max health for `duration` seconds. Drinking again refreshes it.
function Shared.ApplyTeaMax(entity: CharacterEntity, duration: number)
	if entity.Dead then
		return
	end

	entity:SetStatus(Shared.TeaMaxStatus, true, duration)
	entity:SetMaxHealthModifier(TEA_MAX_MODIFIER, TEA_MAX_MULTIPLIER)
	task.delay(duration, function()
		-- Still set means another cup was drunk meanwhile: its own timer removes it.
		if not entity.Dead and not entity:HasStatus(Shared.TeaMaxStatus) then
			entity:SetMaxHealthModifier(TEA_MAX_MODIFIER, nil)
		end
	end)
end

function Shared.ClearTeaMax(entity: CharacterEntity)
	entity:ClearStatus(Shared.TeaMaxStatus)
	if not entity.Dead then
		entity:SetMaxHealthModifier(TEA_MAX_MODIFIER, nil)
	end
end

return Shared
