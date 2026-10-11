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

local FULL_SCORES = { Defense = 10, Melee = 10, Sniper = 10, Sword = 10 }

return function(context: any, slot: number, fruitText: string): string
	local executor: Player = context.Executor
	local data = Knit.GetService("DataService"):GetData(executor)
	if not data then
		return "Your data is not loaded yet."
	elseif slot ~= 1 and slot ~= 2 then
		return "Slot is 1 or 2."
	end

	local FruitService = Knit.GetService("FruitService")
	if string.lower(fruitText) == string.lower(FruitConfig.EmptyName) then
		FruitService:RemoveFruit(executor, slot)
		return `Slot {slot} emptied.`
	end

	local fruitName = resolveFruit(fruitText)
	if not fruitName then
		return `"{fruitText}" is not a fruit.`
	end

	local fruits = data.Data.DevilFruits
	local other = if slot == 1 then fruits.Slot2.Name else fruits.Slot1.Name
	if other == fruitName then
		return "You already have that fruit in the other slot."
	end
	-- Same rule as eating: the second slot needs a first fruit and Legendary Mode.
	if slot == 2 and (other == FruitConfig.EmptyName or not data.Data.Combat.LegendaryMode) then
		return "Slot 2 needs a fruit in slot 1 and Legendary Mode."
	end

	FruitService:RemoveFruit(executor, slot)
	local result = FruitService:EatFruit(executor, fruitName, FULL_SCORES, false)
	return if result == "Slot1" or result == "Slot2" then `{fruitName} set in slot {slot}.` else `Failed ({result}).`
end
