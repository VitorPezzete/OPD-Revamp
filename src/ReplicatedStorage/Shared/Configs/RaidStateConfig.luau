--!strict
--[[
	What a running raid shows to its players. RaidRunService (raid place only) writes
	these Workspace attributes; the RaidHud and RaidWaiting screens read them. Attributes
	reach a late client by themselves and are only sent when their value changes.
]]
export type Phase = "Waiting" | "Running" | "Ended"

return table.freeze({
	Attributes = table.freeze({
		-- Phase: absent until the service has started.
		Phase = "RaidPhase",
		-- Players of the party that have loaded in / how many are expected.
		Arrived = "RaidArrived",
		Expected = "RaidExpected",
		-- Current wave (0 before the first) and enemies still standing.
		Wave = "RaidWave",
		Enemies = "RaidEnemies",
	}),
})
