--!strict
--[[
	Asks DevService whether this client is given a menu, and loads it when it is
	(Client.Modules.MenuLoader). Nothing of the menu is in the client's own code.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local MenuLoader = require(ReplicatedStorage.Client.Modules.MenuLoader)

local DevController = Knit.CreateController({
	Name = "DevController",
})

function DevController:KnitStart()
	MenuLoader.Load(Knit.GetService("DevService"))
end

return DevController
