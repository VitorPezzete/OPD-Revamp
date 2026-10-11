--!strict
--[[
	Fire boss - Flame Pillar. The same travelling column as the Flare fruit's
	(FlarePillar), with the boss's size and timings.
	params: { Direction: Vector3, Distance: number, Speed: number, Size: Vector3,
	          GrowTime: number, Lifetime: number, Haki: boolean, Colors: string }
]]
local FlarePillar = require(script.Parent.FlarePillar)

return function(origin: Vector3, params: { [string]: any }?)
	FlarePillar(origin, params)
end
