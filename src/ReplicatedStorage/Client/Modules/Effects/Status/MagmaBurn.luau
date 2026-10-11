--!strict
--[[
	Magma fruit - burning victim (damage over time left by Great Eruption / Magma Body).
	Status value: true. Runs on players and NPC enemies.

	The legacy BurnMagmaOverTime flag had no visual in the world: the victim only saw the
	"Magma is burning you!" icon on its health bar (StatusIconConfig). Nothing is drawn
	here either.
]]
local function noop() end

return function(_character: Model): () -> ()
	return noop
end
