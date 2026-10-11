--!strict
--[[
	Fire boss - Fire Wave. The same ring as the Flare fruit's (FlareWave), around the boss.
	params: { Radius: number, ExpandTime: number, Lifetime: number, Haki: boolean, Colors: string }
]]
local FlareWave = require(script.Parent.FlareWave)

return function(origin: Vector3, params: { [string]: any }?)
	FlareWave(origin, params)
end
