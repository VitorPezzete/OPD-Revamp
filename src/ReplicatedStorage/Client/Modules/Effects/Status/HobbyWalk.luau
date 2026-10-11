--!strict
--[[
	Hobby fruit - a player toy under orders (HobbyWalk status, value: the Vector3 to walk
	to). Players simulate their own character, so the walk has to be started by the
	toy's own client; the effect restarts whenever the server moves the goal.

	Nothing is trusted from this: the server measures the toy's distance to the kill
	target itself, so a client that refuses to walk only keeps its toy out of the fight.
]]
local function noop() end

return function(character: Model, value: any, isLocal: boolean): () -> ()
	if isLocal and typeof(value) == "Vector3" then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.Sit then
				humanoid.Jump = true
			end
			humanoid:MoveTo(value)
		end
	end
	return noop
end
