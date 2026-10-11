--!strict
--[[
	Chilly fruit - Freezing Punch: the ice ball.

	Nothing is drawn here any more. The ball is a real physical part created and
	simulated by the server (Abilities/Chilly/Freezing Punch), as it was in the legacy
	game, and replicates like any other part. The legacy ball had no particles or sound
	of its own, and the punch clip belongs to Effects.Status.ChillyPunchCharging. The
	module is kept so that a message with this name from an older server is harmless.
]]
return function(_origin: Vector3, _params: { [string]: any }?) end
