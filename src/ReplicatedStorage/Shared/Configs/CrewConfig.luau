--!strict
--[[
	Crew numbers, shared so the crew screen shows the same prices the server charges.
	All prices are in Gems. Values are the legacy ones.
]]
local CrewConfig = {}

CrewConfig.CreatePrice = 2500
CrewConfig.RenamePrice = 1000
CrewConfig.LogoPrice = 500

-- Member slots do not count the owner (the screen shows limit + 1).
CrewConfig.StartMemberLimit = 2
CrewConfig.MaxLevel = 5

CrewConfig.NameMinLength = 3
CrewConfig.NameMaxLength = 20
CrewConfig.InviteSeconds = 60

-- Total experience a crew of this level needs to reach the next one.
function CrewConfig.GetExpRequired(level: number): number
	return 500 * (level + 1) + 2 ^ (level + 3)
end

-- One extra slot can be bought per crew level.
function CrewConfig.CanUpgradeCapacity(level: number, memberLimit: number): boolean
	return memberLimit <= level + 1
end

function CrewConfig.GetCapacityPrice(level: number): number
	return 500 * (level + 1)
end

-- Hard cap implied by the rules above: start + one per level, plus the last purchase.
CrewConfig.MaxMemberLimit = CrewConfig.StartMemberLimit + CrewConfig.MaxLevel

return table.freeze(CrewConfig)
