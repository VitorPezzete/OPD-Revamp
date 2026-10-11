--!strict
--[[
	Hot fruit - passive: none any more.

	This file used to hold the legacy "flight disabler" for Nose Jet only. That rule is
	character-wide (every flight of every fruit) and now lives in
	Server.Modules.FlightLock / AbilityService:RaiseFlightLock; Nose Jet obeys it through
	`Flight = true`. The file is kept as an empty passive and can be deleted.
]]
return function(): () -> ()
	return function() end
end
