--!strict
--[[
	Day / night clock. The server never animates Lighting: it publishes where the clock
	was at a known server time and how fast it runs (Workspace attributes), and every
	machine derives the current hour from that. The legacy game wrote Lighting.ClockTime
	on the server every Heartbeat, replicating 60 property changes per second.
]]
local TimeConfig = {}

-- Game hours per real second (legacy: 0.05, a full day lasts 8 minutes).
TimeConfig.HoursPerSecond = 0.05
-- Hour the clock starts at when a server boots (Lighting.ClockTime of the place).
TimeConfig.StartClockTime = 14

-- Night is NightStart..24 and 0..NightEnd, both ends included (legacy IsDay rule).
TimeConfig.NightStart = 18
TimeConfig.NightEnd = 6

-- Seconds between two local Lighting updates on a client (0.1 s moves the sun 0.075 degrees).
TimeConfig.ClientStep = 0.1

-- Workspace attributes written by TimeService.
TimeConfig.Attributes = table.freeze({
	-- workspace:GetServerTimeNow() at which the clock read OriginClock.
	OriginTime = "ClockOriginTime",
	OriginClock = "ClockOriginHour",
	Rate = "ClockRate",
	Night = "IsNight",
})

-- Settings.Sun_Mode: the local sun stops at this hour (no moving shadows).
TimeConfig.SunModeClockTime = 14
-- Settings.Fog_Mode: local fog distances; Default is what the place ships with.
TimeConfig.Fog = table.freeze({
	Default = table.freeze({ Start = 0, End = 100000 }),
	Enabled = table.freeze({ Start = 0, End = 1500 }),
})

function TimeConfig.IsNight(clockTime: number): boolean
	return clockTime >= TimeConfig.NightStart or clockTime <= TimeConfig.NightEnd
end

-- Hour of the day (0-24) at server time `now`.
function TimeConfig.GetClockTime(originTime: number, originClock: number, rate: number, now: number): number
	return (originClock + (now - originTime) * rate) % 24
end

return table.freeze(TimeConfig)
