--!strict
--[[
	More fruit - passive: nothing while the fruit is owned. Its cleanup is the point: when
	the user dies, leaves or loses the fruit, everyone it resized (itself included) goes
	back to normal size. The legacy script did this on death only.

	This is a passive and not Resize Other's OnInterrupt because OnInterrupt also runs when
	the user is merely stunned or sealed, which did not free the victims.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local MoreScale = require(ServerStorage.Server.Modules.Abilities.More.MoreScale)

return function(entity: CharacterEntity.CharacterEntity): () -> ()
	return function()
		MoreScale.RestoreOwnedBy(entity, true)
	end
end
