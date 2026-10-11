--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Permissions = require(ServerStorage.Server.Modules.Permissions)

return function(context: any, target: Player): string
	local executor: Player = context.Executor
	if target ~= executor and not Permissions.CanTarget(executor, target.UserId) then
		return "You cannot bring that player."
	end

	local CharacterService = Knit.GetService("CharacterService")
	local own = CharacterService:GetPlayerEntity(executor)
	local other = CharacterService:GetPlayerEntity(target)
	if not own or not other or own.Dead or other.Dead then
		return "Both characters must be alive."
	end
	CharacterService:Teleport(other, own.Root.CFrame)
	return `Brought {target.Name}.`
end
