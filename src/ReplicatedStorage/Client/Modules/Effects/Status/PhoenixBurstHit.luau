--!strict
--[[
	Phoenix fruit - a character thrown by a Phoenix Burst (0.18 s).

	The legacy server set PlatformStand on the victim's humanoid for as long as its
	knockback mover lived, so the character was carried without its legs holding the
	ground. A player's humanoid is driven by its own client: this is that client's side.
	NPCs get the same from the server (Abilities/Phoenix/Phoenix Burst).

	The hold is counted (Effects.Util.Limp): the legacy script put back the PlatformStand
	it had found, which left a character limp for good when the burst landed on one that
	was already limp for another reason.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Limp = require(ReplicatedStorage.Client.Modules.Effects.Util.Limp)

return function(character: Model, _value: any, isLocal: boolean): () -> ()
	local humanoid = if isLocal then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return function() end
	end

	return Limp.hold(humanoid)
end
