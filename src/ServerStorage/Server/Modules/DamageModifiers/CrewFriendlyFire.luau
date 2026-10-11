--!strict
--[[
	Crew Wars friendly fire. The legacy game never protected crewmates in the open world:
	the only rule (Damage, "Crew Wars: Friendly Fire Protection") cancelled hits between
	two characters carrying the same non-empty CrewWarsTeam tag, which the Crew Wars world
	event put on its participants.

	The tag is now the character attribute "CrewWarsTeam" (the crew id), set and cleared
	by whoever runs the event. With no event running nothing is tagged and this does nothing.
]]
local ServerStorage = game:GetService("ServerStorage")

local CombatTypes = require(ServerStorage.Server.Types.CombatTypes)

local TEAM_ATTRIBUTE = "CrewWarsTeam"

return {
	Name = "CrewFriendlyFire",
	-- Before shields and perks: a cancelled hit must not burn either.
	Priority = 40,
	Apply = function(context: CombatTypes.DamageContext)
		local attacker = context.Attacker
		if not attacker or attacker == context.Target then
			return
		end

		local team = context.Target.Model:GetAttribute(TEAM_ATTRIBUTE)
		if type(team) == "string" and team ~= "" and attacker.Model:GetAttribute(TEAM_ATTRIBUTE) == team then
			context.Cancelled = true
			context.CancelReason = "FriendlyFire"
		end
	end,
} :: CombatTypes.DamageModifier
