--!strict
--[[
	Fruit effect colors. A fruit item may roll a custom pair ("aura"), saved as
	"r,g,b,r,g,b"; "None" means the effect keeps its authored colors.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)

local FruitColor = {}

-- Parses the saved string. Returns nil for "None" or anything malformed.
function FruitColor.Parse(saved: string): (Color3?, Color3?)
	local parts = string.split(saved, ",")
	if #parts ~= 6 then
		return nil, nil
	end

	local channels = table.create(6)
	for index, part in parts do
		local channel = tonumber(part)
		if not channel then
			return nil, nil
		end
		channels[index] = math.clamp(channel, 0, 255)
	end
	return Color3.fromRGB(channels[1], channels[2], channels[3]), Color3.fromRGB(channels[4], channels[5], channels[6])
end

function FruitColor.Serialize(primary: Color3, secondary: Color3): string
	local function channel(value: number): number
		return math.round(value * 255)
	end
	return string.format(
		"%d,%d,%d,%d,%d,%d",
		channel(primary.R),
		channel(primary.G),
		channel(primary.B),
		channel(secondary.R),
		channel(secondary.G),
		channel(secondary.B)
	)
end

-- The color string an eaten fruit saves when its item rolled an aura.
function FruitColor.GetDefault(fruitName: string): string?
	local fruit = FruitConfig.Fruits[fruitName]
	local colors = fruit and fruit.DefaultColors
	return if colors then FruitColor.Serialize(colors[1], colors[2]) else nil
end

function FruitColor.ToSequence(primary: Color3, secondary: Color3): ColorSequence
	return ColorSequence.new(primary, secondary)
end

return FruitColor
