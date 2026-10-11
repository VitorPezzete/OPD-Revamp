--!strict
--[[
	Hobby fruit - Revert: frees every toy of the user. Transformed characters get their
	body, controls and powers back; claimed toy soldiers are removed.

	The same release runs when the user dies, leaves or loses the fruit (Passives/Hobby).

	Legacy problem fixed here: the restore code existed twice (here and in the death
	handler) and both yielded inside the loop over the shared toy table.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Toys = require(script.Parent._Toys)

local Revert = Ability.extend()

function Revert:OnBegin()
	Toys.ReleaseAll(self.Entity)
end

return Revert
