--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

return function(context: any): string
	local executor: Player = context.Executor
	local entity = Knit.GetService("CharacterService"):GetPlayerEntity(executor)
	if not entity or entity.Dead then
		return "You need a living character to start a drop party."
	end

	local dropped = Knit.GetService("FruitBoxService"):DropParty(entity.Root.Position)
	return `Dropped {dropped} box(es).`
end
