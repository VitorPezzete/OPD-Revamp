--!strict
--[[
	Asks AdminService whether this client is given a menu, and loads it when it is
	(Client.Modules.MenuLoader). Nothing of the menu is in the client's own code.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local MenuLoader = require(ReplicatedStorage.Client.Modules.MenuLoader)

local AdminController = Knit.CreateController({
	Name = "AdminController",
})

function AdminController:KnitStart()
	MenuLoader.Load(Knit.GetService("AdminService"))
end

return AdminController
