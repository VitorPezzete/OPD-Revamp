--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any): string
	local entity = Knit.GetService("CharacterService"):GetPlayerEntity(context.Executor)
	if not entity or entity.Dead then
		return "You have no living character."
	end
	entity:Heal(entity.MaxHealth)
	return "Healed."
end
