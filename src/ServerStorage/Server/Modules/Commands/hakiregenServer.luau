--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Permissions = require(ServerStorage.Server.Modules.Permissions)

return function(context: any, everyone: boolean?): string
	local executor: Player = context.Executor
	if everyone and not Permissions.Has(executor, "Owner") then
		return "Only owners can refill the whole server."
	end

	local CharacterService = Knit.GetService("CharacterService")
	local HakiService = Knit.GetService("HakiService")
	local refilled = 0
	for _, player in if everyone then Players:GetPlayers() else { executor } do
		local entity = CharacterService:GetPlayerEntity(player)
		if entity then
			local _, maximum = HakiService:GetBar(entity)
			if maximum > 0 and HakiService:AddBar(entity, maximum) then
				refilled += 1
			end
		end
	end
	return `Refilled {refilled} haki bar(s).`
end
