--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any, target: Player): string
	local CharacterService = Knit.GetService("CharacterService")
	local own = CharacterService:GetPlayerEntity(context.Executor)
	local other = CharacterService:GetPlayerEntity(target)
	if not own or not other or own.Dead or other.Dead then
		return "Both characters must be alive."
	end
	CharacterService:Teleport(own, other.Root.CFrame)
	return `Teleported to {target.Name}.`
end
