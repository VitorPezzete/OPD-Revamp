--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AdminConfig = require(ServerStorage.Server.Configs.AdminConfig)

return function(context: any): string
	local CharacterService = Knit.GetService("CharacterService")
	local entity = CharacterService:GetPlayerEntity(context.Executor)
	if not entity or entity.Dead then
		return "You have no living character."
	end
	CharacterService:Teleport(entity, AdminConfig.AdminZone)
	return "Teleported to the admin zone."
end
