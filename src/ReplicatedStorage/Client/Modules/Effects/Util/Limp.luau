--!strict
--[[
	A character gone limp (Humanoid.PlatformStand) for as long as one of its statuses says
	so: thrown by a Quake Stomp or a Phoenix Burst, flattened by Crushing Force, severed.

		local stand = Limp.hold(humanoid)
		stand()   -- that status ended: the character stands, unless another still holds it

	The holds are counted. Each status used to write the property by itself, two of them
	putting back whatever they had found: a stomp that landed on a character already limp
	and outlasted what had made it so put "limp" back for good, and its victim could use
	every power but could not walk until it respawned.

	Only the owning client drives its humanoid: this is for the local character.
]]
local Limp = {}

local holds: { [Humanoid]: number } = setmetatable({} :: any, { __mode = "k" })

function Limp.hold(humanoid: Humanoid): () -> ()
	holds[humanoid] = (holds[humanoid] or 0) + 1
	humanoid.PlatformStand = true

	local held = true
	return function()
		if not held then
			return
		end
		held = false

		local left = (holds[humanoid] or 1) - 1
		holds[humanoid] = if left > 0 then left else nil
		if left <= 0 and humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end
end

return Limp
