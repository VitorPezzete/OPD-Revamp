--!strict
--[[
	Tools that are used rather than swung: the utility-slot items (fishing rods are a
	system of their own) and the grapples. Numbers from the legacy tool scripts.

	Cooldown is the legacy client debounce, now also enforced by the server.
]]
export type UtilityDefinition = {
	Kind: "TeaCup" | "TeaKettle" | "ZombieHead" | "Grapple",
	Cooldown: number,
	-- Clip played by the user: key of AnimationConfig.Weapons[tool], and its speed.
	Animation: string?,
	AnimationSpeed: number?,
	-- Grapple: longest rope, in studs.
	MaxDistance: number?,
}

local Tools: { [string]: UtilityDefinition } = {
	-- A sip takes 6 s and counts one tea.
	["Tea Cup"] = { Kind = "TeaCup", Cooldown = 6, Animation = "Animation", AnimationSpeed = 1 },
	-- Pours a cup for the player in front.
	["Tea Kettle"] = { Kind = "TeaKettle", Cooldown = 6, Animation = "Animation", AnimationSpeed = 0.5 },
	-- Turns whoever is in front zombie green.
	["Zombie Head"] = { Kind = "ZombieHead", Cooldown = 0.5, Animation = "Animation", AnimationSpeed = 12 },

	["Small Grapple"] = { Kind = "Grapple", Cooldown = 0.5, MaxDistance = 7 },
	["Medium Grapple"] = { Kind = "Grapple", Cooldown = 0.5, MaxDistance = 20 },
	["Large Grapple"] = { Kind = "Grapple", Cooldown = 0.5, MaxDistance = 40 },
}

return table.freeze({
	Tools = table.freeze(Tools),

	-- Teas drunk to be given the Tea Kettle.
	TeaForKettle = 100,
	-- Box in front of the user reached by the kettle and the zombie head.
	ReachSize = Vector3.new(4, 3, 3),
	ReachDistance = 2,
	ZombieColor = Color3.fromRGB(0, 60, 0),
	RopeThickness = 0.5,
})
