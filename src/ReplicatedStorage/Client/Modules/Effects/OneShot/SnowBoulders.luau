--!strict
--[[
	Snow fruit - Snow Boulder: nothing to draw any more.

	The boulders used to be points simulated by the server and drawn here. They are the
	legacy physical parts again (Abilities.Snow["Snow Boulder"]: a pushed, rideable Seat
	cannot be faked with a drawing), created, colored and faded by the server and
	replicated like any part. The server no longer plays this effect; the module only
	remains so that a call from an older server build is harmless. It can be deleted.
]]
return function(_origin: Vector3, _params: { [string]: any }?) end
