--!strict
--[[
	The two strings existing profiles use for a fruit that is not in a fruit slot.
	The formats are kept so old saves keep working; both sides parse them here.

	Stored item (Storages.<n>.Item):   "<Fruit> Fruit,<def>,<melee>,<sniper>,<sword>,<aura>"
		affinity scores 0-10; the last field is the item's aura roll, where 1 is an aura.
	Bound fruit (Bounds.<n>.Fruit):    "<Fruit>,<def>,<melee>,<sniper>,<sword>,<color...>"
		affinity multipliers 1.0-2.0; color is "None" or six channels "r,g,b,r,g,b".
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)

export type Scores = { Defense: number, Melee: number, Sniper: number, Sword: number }

export type StoredItem = { FruitName: string, Scores: Scores, HasAura: boolean }
export type BoundFruit = { FruitName: string, Affinities: Scores, Color: string }

local EMPTY = "None"
local ITEM_SUFFIX = " Fruit"
-- Any roll above 1 means "no aura". The legacy game wrote its random roll here.
local AURA_ROLL = 1
local PLAIN_ROLL = 2

local FruitItemCodec = {}

FruitItemCodec.Empty = EMPTY

local function readNumber(text: string?, minimum: number, maximum: number, default: number): number
	local value = tonumber(text)
	if not value or value ~= value then
		return default
	end
	return math.clamp(value, minimum, maximum)
end

function FruitItemCodec.EncodeItem(item: StoredItem): string
	local scores = item.Scores
	return string.format(
		"%s%s,%d,%d,%d,%d,%d",
		item.FruitName,
		ITEM_SUFFIX,
		scores.Defense,
		scores.Melee,
		scores.Sniper,
		scores.Sword,
		if item.HasAura then AURA_ROLL else PLAIN_ROLL
	)
end

-- nil for "None", an unknown fruit or a malformed string.
function FruitItemCodec.DecodeItem(saved: unknown): StoredItem?
	if type(saved) ~= "string" or saved == EMPTY then
		return nil
	end

	local parts = string.split(saved, ",")
	-- Old tools were named "<Fruit> Fruit" (one of them with a double space).
	local fruitName = string.match(parts[1], "^(%S+)")
	if not fruitName or not FruitConfig.Fruits[fruitName] then
		return nil
	end

	local aura = tonumber(parts[6])
	return {
		FruitName = fruitName,
		Scores = {
			Defense = math.floor(readNumber(parts[2], 0, 10, 0)),
			Melee = math.floor(readNumber(parts[3], 0, 10, 0)),
			Sniper = math.floor(readNumber(parts[4], 0, 10, 0)),
			Sword = math.floor(readNumber(parts[5], 0, 10, 0)),
		},
		HasAura = aura ~= nil and aura <= AURA_ROLL,
	}
end

function FruitItemCodec.EncodeBound(bound: BoundFruit): string
	local affinities = bound.Affinities
	return string.format(
		"%s,%g,%g,%g,%g,%s",
		bound.FruitName,
		affinities.Defense,
		affinities.Melee,
		affinities.Sniper,
		affinities.Sword,
		bound.Color
	)
end

function FruitItemCodec.DecodeBound(saved: unknown): BoundFruit?
	if type(saved) ~= "string" or saved == EMPTY then
		return nil
	end

	local parts = string.split(saved, ",")
	local fruitName = parts[1]
	if not FruitConfig.Fruits[fruitName] then
		return nil
	end

	local color = EMPTY
	if #parts >= 11 then
		local channels = table.create(6)
		for index = 6, 11 do
			table.insert(channels, tostring(math.floor(readNumber(parts[index], 0, 255, 0))))
		end
		color = table.concat(channels, ",")
	end

	return {
		FruitName = fruitName,
		Affinities = {
			Defense = readNumber(parts[2], 1, 2, 1),
			Melee = readNumber(parts[3], 1, 2, 1),
			Sniper = readNumber(parts[4], 1, 2, 1),
			Sword = readNumber(parts[5], 1, 2, 1),
		},
		Color = color,
	}
end

return table.freeze(FruitItemCodec)
