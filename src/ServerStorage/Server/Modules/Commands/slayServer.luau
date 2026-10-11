--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local Permissions = require(ServerStorage.Server.Modules.Permissions)

return function(context: any, target: Player): string
	local executor: Player = context.Executor
	if target ~= executor and not Permissions.CanTarget(executor, target.UserId) then
		return "You cannot slay that player."
	end

	local entity = Knit.GetService("CharacterService"):GetPlayerEntity(target)
	if not entity or entity.Dead then
		return `{target.Name} has no living character.`
	end
	entity:Kill()
	return `Slew {target.Name}.`
end
