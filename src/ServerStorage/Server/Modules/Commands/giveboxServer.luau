--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local TreasureConfig = require(ReplicatedStorage.Shared.Configs.TreasureConfig)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)

local function resolve(names: { [string]: any }, text: string): string?
	local wanted = string.lower(text)
	for name in names do
		if string.lower(name) == wanted then
			return name
		end
	end
	return nil
end

return function(context: any, itemText: string, receiver: Player?): string
	local target: Player = receiver or context.Executor

	-- A box found this way has no finder: its fruit belongs to whoever opens it.
	local boxName = resolve(TreasureConfig.Boxes, itemText)
	if boxName then
		local box = Knit.GetService("FruitBoxService"):Give(target, boxName)
		return if box then `Gave {boxName} to {target.Name}.` else `{target.Name} has no backpack.`
	end

	-- TreasureService gives the compass its treasure when it lands in the backpack.
	local compassName = resolve(TreasureConfig.Compasses, itemText)
	if compassName then
		local compass = ToolTemplates.Give(target, compassName, "Items")
		return if compass then `Gave {compassName} to {target.Name}.` else `{target.Name} has no backpack.`
	end

	return `"{itemText}" is not a box or a compass.`
end
