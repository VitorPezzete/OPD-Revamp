--!strict
--[[
	Hobby fruit - Command: every toy of the user walks to the aimed point.

	Player toys lose their own controls from their first order on (HobbyControlled
	status) and see one of the "go there" lines. The order replaces a running Target
	order and ends when every toy has arrived, or after 8 s (the legacy order was one
	Humanoid:MoveTo, which gives up after that long).

	Legacy problems fixed here:
	- The destination was a CFrame sent by the client with no check at all; it is the
	  aim point AbilityService validated (finite, within range of the user).
	- The toy list was shared by every use of the script and never pruned of characters
	  that had left; ownership is resolved in the server registry.
]]
local ServerStorage = game:GetService("ServerStorage")

local Ability = require(ServerStorage.Server.Classes.Ability)
local Toys = require(script.Parent._Toys)

local Command = Ability.extend()

function Command:OnBegin(input: Ability.AbilityInput)
	Toys.Command(self.Entity, input.AimPosition)
end

return Command
