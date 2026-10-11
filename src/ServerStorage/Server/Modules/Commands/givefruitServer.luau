--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)

local function resolveFruit(text: string): string?
	local wanted = string.lower(text)
	for name in FruitConfig.Fruits do
		if string.lower(name) == wanted then
			return name
		end
	end
	return nil
end

local function score(value: number?, rolled: number): number
	return if value then math.clamp(math.floor(value), 0, 10) else rolled
end

return function(
	context: any,
	fruitText: string,
	receiver: Player?,
	defense: number?,
	melee: number?,
	sniper: number?,
	sword: number?
): string
	local target: Player = receiver or context.Executor
	local fruitName = resolveFruit(fruitText)
	if not fruitName then
		return `"{fruitText}" is not a fruit.`
	end

	local backpack = target:FindFirstChildOfClass("Backpack")
	if not backpack then
		return `{target.Name} has no backpack.`
	end

	local FruitService = Knit.GetService("FruitService")
	local rolled = FruitService:RollScores()
	local scores = {
		Defense = score(defense, rolled.Defense),
		Melee = score(melee, rolled.Melee),
		Sniper = score(sniper, rolled.Sniper),
		Sword = score(sword, rolled.Sword),
	}

	local tool = FruitService:CreateItem(fruitName, scores, false)
	if not tool then
		return `{fruitName} has no item model.`
	end
	tool.Parent = backpack
	return `Gave {fruitName} ({scores.Defense}/{scores.Melee}/{scores.Sniper}/{scores.Sword}) to {target.Name}.`
end
