--!strict
--[[
	One-use items (the drinks of ServerStorage.Juices in the legacy place).
	Each drink took 2 seconds to drink and then gave experience in one skill,
	scaled by the server exp multiplier.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)

export type Consumable = {
	Skill: DataTypes.SkillName,
	Exp: number,
}

local Consumables: { [string]: Consumable } = {
	Cider = { Skill = "Melee", Exp = 120 },
	Juice = { Skill = "Sword", Exp = 120 },
	Lemonade = { Skill = "Sniper", Exp = 120 },
	Smoothie = { Skill = "Defense", Exp = 30 },
	["Cider+"] = { Skill = "Melee", Exp = 2000 },
	["Juice+"] = { Skill = "Sword", Exp = 2000 },
	["Lemonade+"] = { Skill = "Sniper", Exp = 2000 },
	["Smoothie+"] = { Skill = "Defense", Exp = 500 },
}

return table.freeze({
	Consumables = table.freeze(Consumables),
	-- Time between the click and the effect; the drinking animation covers it.
	UseSeconds = 2,
	-- Not legacy: the old shops let a rich player fill the server with tools.
	MaxCarried = 20,
})
