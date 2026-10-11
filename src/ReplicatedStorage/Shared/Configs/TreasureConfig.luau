--!strict
--[[
	The treasure compasses and the devil fruit boxes they dig up, as far as the client
	needs to know them (legacy ServerStorage.Backups.<Compass>.CompassServer and
	ServerStorage.Boxes). Odds, fruit pools and target rules are server-only:
	Server.Configs.FruitBoxConfig.

	The Burning Compass is a different system (CompassConfig / CompassService).
]]

export type Compass = {
	-- Distance to the treasure at which it is dug up.
	ArrivalRadius: number,
}

local function compass(arrivalRadius: number): Compass
	return table.freeze({ ArrivalRadius = arrivalRadius })
end

return table.freeze({
	-- Vector3 attribute the server puts on a compass Tool: where its treasure is buried.
	TargetAttribute = "TreasureTarget",
	-- Boolean attribute: the tool kept its second needle model, which is mounted mirrored.
	NeedleFlipAttribute = "TreasureNeedleFlip",

	-- Tools are recognised by name, wherever they were handed out.
	Compasses = table.freeze({
		["Compass"] = compass(5),
		["Silver Compass"] = compass(5),
		["Golden Compass"] = compass(5),
		["Strange Compass"] = compass(5),
		-- The same reach as the Strange Compass: the old 3 studs was too small to hit.
		["??? Strange Compass"] = compass(5),
	} :: { [string]: Compass }),

	-- Tools opened by using them while held.
	Boxes = table.freeze({
		["Common Box"] = true,
		["Uncommon Box"] = true,
		["Rare Box"] = true,
		["Ultra Rare Box"] = true,
		["Strange Common Box"] = true,
		["Strange Uncommon Box"] = true,
		["Strange Rare Box"] = true,
		["Strange Ultra Rare Box"] = true,
	} :: { [string]: boolean }),
})
