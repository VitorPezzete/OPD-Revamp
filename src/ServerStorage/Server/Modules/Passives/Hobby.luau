--!strict
--[[
	Hobby fruit - passive. Nothing is granted while the fruit is owned; the passive
	exists for its cleanup, which runs when the character dies or leaves and when the
	fruit is removed: every toy of the user is freed (and every toy soldier removed).

	This is deliberately not in an ability's OnInterrupt: that also runs on every stun
	and seal, and a stunned Hobby user keeps its toys, as in the legacy game.
]]
local ServerStorage = game:GetService("ServerStorage")

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local Toys = require(ServerStorage.Server.Modules.Abilities.Hobby._Toys)

return function(entity: CharacterEntity.CharacterEntity): () -> ()
	return function()
		Toys.ReleaseAll(entity)
	end
end
