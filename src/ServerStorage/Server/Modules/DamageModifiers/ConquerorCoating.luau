--!strict
--[[
	Conqueror's Haki, stage 3 - the coating (ConquerorCoating status): the wearer's hits
	do 15% more, and hits on the wearer do 15% less, or only 7.5% less while the wearer
	is stunned.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ConquerorConfig = require(ReplicatedStorage.Shared.Configs.ConquerorConfig)
local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local COATING = ConquerorConfig.Coating
local COATING_STATUS = ConquerorConfig.Status.Coating
local STUN_STATUS = "Stunned"

return {
	Name = "ConquerorCoating",
	-- With the other attacker bonuses (100, 110) and before the shield (200), which the
	-- softened hit is then taken from.
	Priority = 120,
	Apply = function(context: CombatTypes.DamageContext)
		local attacker = context.Attacker
		if attacker and attacker:HasStatus(COATING_STATUS) then
			context.Amount *= COATING.DamageDealt
		end

		local target = context.Target
		if target:HasStatus(COATING_STATUS) then
			context.Amount *= if target:HasStatus(STUN_STATUS) then COATING.DamageTakenStunned else COATING.DamageTaken
		end
	end,
} :: CombatTypes.DamageModifier
