--!strict
--[[
	GENERATED from the legacy place (Powers.<Fruit>.PowerN values, ReplicatedStorage.DFUs
	and the ServerStorage.Fruits rarity folders). Edit freely: nothing regenerates it.

	Released = the fruit tool existed in a drop folder of the old game.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)

export type FruitRarity = "Common" | "Uncommon" | "Rare" | "UltraRare" | "Event" | "Unreleased"

export type AbilityDefinition = {
	-- Hotkey slot of the fruit (1-6 -> DF?A..DF?F).
	Slot: number,
	Name: string,
	-- Skill whose level gates the ability.
	Skill: DataTypes.SkillName,
	Requirement: number,
	-- The key charges: the HUD draws a charge bar from the press on.
	Chargeable: boolean?,
	MaxCharge: number?,
	-- What the key does for the ability, when it is not what Chargeable says (see GetPress).
	Press: Press?,
	-- Switched off: GetAbility answers nil for it, so the server refuses the press and
	-- every bar and panel draws its slot as an empty one. The other abilities of the
	-- fruit keep their slots and keys. Remove the field to bring the ability back.
	Disabled: boolean?,
}

--[[
	How an ability uses its key, read off its server module (Server.Modules.Abilities):
	- "Single":    the press is everything. Nothing happens on the release that the press
	               did not already decide; this includes the abilities the server toggles
	               (a press turns them on, the next press off).
	- "Charge":    the key is held and the release is the cast: a charge (BeginCharge /
	               EndCharge), or an ability aimed while held and placed on release.
	- "Sustained": the ability lasts for as long as the key is down (a stream, a beam, a
	               roll) and letting go ends it.
	The client uses it to pick how a touch button behaves in the "Auto" control layout
	(ControlsConfig.Auto); the server never reads it.
]]
export type Press = "Single" | "Charge" | "Sustained"

export type FruitDefinition = {
	Rarity: FruitRarity,
	Released: boolean,
	-- Primary / secondary effect colors when the item rolled no custom color.
	DefaultColors: { Color3 }?,
	Abilities: { AbilityDefinition },
}

local Fruits: { [string]: FruitDefinition } = {
	Alice = {
		Rarity = "Event",
		Released = false,
		DefaultColors = { Color3.fromRGB(255, 154, 65), Color3.fromRGB(255, 255, 0) },
		Abilities = {
			{ Slot = 1, Name = "Cards of Fate", Skill = "Haki", Requirement = 150 },
			{ Slot = 2, Name = "Tea Party", Skill = "Haki", Requirement = 200 },
			{ Slot = 3, Name = "Wonderland Delirium", Skill = "Haki", Requirement = 300 },
			{ Slot = 4, Name = "Cheshire's Grin", Skill = "Haki", Requirement = 400 },
			{ Slot = 5, Name = "Looking Glass", Skill = "Haki", Requirement = 450 },
			{ Slot = 6, Name = "Wonderland", Skill = "Haki", Requirement = 500 },
		},
	},
	Barrier = {
		Rarity = "Uncommon",
		Released = true,
		DefaultColors = { Color3.fromRGB(120, 204, 220), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Wall", Skill = "Defense", Requirement = 25 },
			{ Slot = 2, Name = "Slam", Skill = "Melee", Requirement = 50 },
			{ Slot = 3, Name = "Prison", Skill = "Defense", Requirement = 300, Press = "Charge" },
			{ Slot = 4, Name = "Room", Skill = "Defense", Requirement = 100 },
			{ Slot = 5, Name = "Barrier Bat", Skill = "Melee", Requirement = 200 },
			{ Slot = 6, Name = "Barrier Body", Skill = "Defense", Requirement = 400 },
		},
	},
	Blood = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(50, 130, 255), Color3.fromRGB(157, 50, 215) },
		Abilities = {
			{ Slot = 1, Name = "Blood Hemomancy", Skill = "Defense", Requirement = 50 },
			{ Slot = 2, Name = "Blood Convergence", Skill = "Sniper", Requirement = 200 },
			{ Slot = 3, Name = "Blood Supernova", Skill = "Defense", Requirement = 200 },
			{ Slot = 4, Name = "Blood Surge", Skill = "Defense", Requirement = 350, Press = "Sustained" },
			{ Slot = 6, Name = "Blood Concentrate", Skill = "Defense", Requirement = 400 },
		},
	},
	Bomb = {
		Rarity = "Uncommon",
		Released = true,
		DefaultColors = { Color3.fromRGB(90, 99, 184), Color3.fromRGB(0, 255, 0) },
		Abilities = {
			{ Slot = 1, Name = "Bomb Punch", Skill = "Melee", Requirement = 50, Chargeable = true },
			{ Slot = 2, Name = "Bomb Boost", Skill = "Melee", Requirement = 50, Chargeable = true },
			{ Slot = 5, Name = "Bomb Wave", Skill = "Sniper", Requirement = 300, Chargeable = true },
			{ Slot = 6, Name = "Full Body", Skill = "Defense", Requirement = 400, Chargeable = true },
		},
	},
	Candy = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 120, 255), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Syrup Blades", Skill = "Sword", Requirement = 50 },
			{ Slot = 2, Name = "Spike Body", Skill = "Defense", Requirement = 75 },
			{ Slot = 3, Name = "Jawbreaker", Skill = "Sniper", Requirement = 100, Chargeable = true },
			{ Slot = 4, Name = "Syrup Trap", Skill = "Defense", Requirement = 125 },
			{ Slot = 5, Name = "Syrup Wave", Skill = "Melee", Requirement = 150 },
			{ Slot = 6, Name = "Syrup Hook", Skill = "Sniper", Requirement = 175 },
		},
	},
	Chilly = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(205, 181, 218), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Chilly Sword", Skill = "Sword", Requirement = 50 },
			{ Slot = 2, Name = "Freezing Punch", Skill = "Melee", Requirement = 100, Chargeable = true },
			{ Slot = 3, Name = "Ice Path", Skill = "Melee", Requirement = 70 },
			{ Slot = 5, Name = "Ice Wave", Skill = "Sniper", Requirement = 400, Chargeable = true },
		},
	},
	Chop = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(30, 30, 30), Color3.fromRGB(240, 240, 240) },
		Abilities = {
			{ Slot = 1, Name = "Chop Choke", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Chop Pursuit", Skill = "Sword", Requirement = 150 },
			{ Slot = 3, Name = "Chop Car", Skill = "Melee", Requirement = 200 },
		},
	},
	Clear = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(127, 127, 127), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Invisibility", Skill = "Melee", Requirement = 50 },
		},
	},
	Clone = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(127, 127, 127), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Undo", Skill = "Melee", Requirement = 10 },
			{ Slot = 2, Name = "Morph", Skill = "Melee", Requirement = 10 },
			{ Slot = 3, Name = "Steal", Skill = "Melee", Requirement = 10 },
			{ Slot = 4, Name = "Clone Rush", Skill = "Melee", Requirement = 100 },
			{ Slot = 5, Name = "Dapper Duplication", Skill = "Defense", Requirement = 100 },
			{ Slot = 6, Name = "Copycat", Skill = "Defense", Requirement = 150 },
		},
	},
	Dark = {
		Rarity = "UltraRare",
		Released = true,
		DefaultColors = { Color3.fromRGB(49, 44, 75), Color3.fromRGB(50, 0, 0) },
		Abilities = {
			{ Slot = 1, Name = "Dark Charge", Skill = "Defense", Requirement = 200, Press = "Charge" },
			{ Slot = 2, Name = "Dark Vortex", Skill = "Melee", Requirement = 50 },
			{ Slot = 3, Name = "Black Hole", Skill = "Defense", Requirement = 80 },
			{ Slot = 4, Name = "Dark Star", Skill = "Sniper", Requirement = 200, Chargeable = true },
		},
	},
	Diamond = {
		Rarity = "Uncommon",
		Released = true,
		DefaultColors = { Color3.fromRGB(205, 189, 255), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Diamond Blade", Skill = "Sword", Requirement = 50 },
			{ Slot = 2, Name = "Diamond Body", Skill = "Defense", Requirement = 20 },
			{ Slot = 3, Name = "Diamond Cluster", Skill = "Defense", Requirement = 80, Chargeable = true },
		},
	},
	Door = {
		Rarity = "Unreleased",
		Released = false,
		Abilities = {
			{ Slot = 1, Name = "Door Strike", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Escape Door", Skill = "Defense", Requirement = 75 },
			{ Slot = 3, Name = "Crushing Gate", Skill = "Melee", Requirement = 250 },
			{ Slot = 4, Name = "Dimensional Trap", Skill = "Defense", Requirement = 400 },
		},
	},
	Dough = {
		Rarity = "UltraRare",
		Released = true,
		DefaultColors = { Color3.fromRGB(245, 205, 48), Color3.fromRGB(196, 40, 28) },
		Abilities = {
			{ Slot = 1, Name = "Burning Mochi", Skill = "Sniper", Requirement = 300, Chargeable = true, MaxCharge = 5 },
			{ Slot = 2, Name = "Dough Bazooka", Skill = "Melee", Requirement = 250, Chargeable = true, MaxCharge = 5 },
			{ Slot = 3, Name = "Mochi Gatling", Skill = "Melee", Requirement = 500, Press = "Sustained" },
			{ Slot = 4, Name = "Donut Roll", Skill = "Melee", Requirement = 300, Press = "Sustained" },
			{ Slot = 5, Name = "Mochi Wasteland", Skill = "Defense", Requirement = 450 },
			{ Slot = 6, Name = "Torque Mochi", Skill = "Defense", Requirement = 500, Chargeable = true, MaxCharge = 10, Press = "Sustained" },
		},
	},
	Flare = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(145, 255, 0), Color3.fromRGB(255, 200, 0) },
		Abilities = {
			{ Slot = 1, Name = "Jet", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Fire Fist", Skill = "Sniper", Requirement = 50, Chargeable = true },
			{ Slot = 4, Name = "Fire Wave", Skill = "Defense", Requirement = 200 },
			{ Slot = 5, Name = "Flame Pillar", Skill = "Defense", Requirement = 250, Chargeable = true },
			{ Slot = 6, Name = "Flame Emperor", Skill = "Sniper", Requirement = 400, Chargeable = true, MaxCharge = 500 },
		},
	},
	Float = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 255, 0), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Float", Skill = "Melee", Requirement = 50 },
			{ Slot = 2, Name = "Ascend", Skill = "Melee", Requirement = 100, Press = "Sustained" },
			{ Slot = 3, Name = "Levitate", Skill = "Melee", Requirement = 200 },
		},
	},
	Gas = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(196, 40, 28), Color3.fromRGB(255, 0, 0) },
		Abilities = {
			{ Slot = 1, Name = "Gas Form", Skill = "Melee", Requirement = 200 },
			{ Slot = 2, Name = "Blue Sword", Skill = "Sword", Requirement = 50 },
			{ Slot = 3, Name = "Airless World", Skill = "Defense", Requirement = 100 },
			{ Slot = 4, Name = "Gastille", Skill = "Sniper", Requirement = 200, Chargeable = true },
		},
	},
	Gravity = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 0, 81), Color3.fromRGB(112, 99, 255) },
		Abilities = {
			{ Slot = 1, Name = "Gravity Flying", Skill = "Defense", Requirement = 200 },
			{ Slot = 2, Name = "Gravity Repel", Skill = "Sniper", Requirement = 75, Chargeable = true },
			{ Slot = 3, Name = "Gravity Assault", Skill = "Sniper", Requirement = 100, Press = "Sustained" },
			{ Slot = 4, Name = "Crushing Force", Skill = "Defense", Requirement = 300, Chargeable = true },
			{ Slot = 5, Name = "Meteor Shower", Skill = "Sniper", Requirement = 300, Chargeable = true },
			{ Slot = 6, Name = "Meteor Crash", Skill = "Sniper", Requirement = 400, Chargeable = true },
		},
	},
	Gum = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(101, 196, 214), Color3.fromRGB(255, 115, 117) },
		Abilities = {
			{ Slot = 1, Name = "Pistol", Skill = "Melee", Requirement = 25 },
			{ Slot = 2, Name = "Bazooka", Skill = "Melee", Requirement = 50 },
			{ Slot = 3, Name = "Gatling", Skill = "Melee", Requirement = 75, Press = "Sustained" },
			{ Slot = 4, Name = "Gum Rocket", Skill = "Melee", Requirement = 100, Press = "Charge" },
			{ Slot = 5, Name = "2nd Gear", Skill = "Melee", Requirement = 100 },
		},
	},
	Hobby = {
		Rarity = "Uncommon",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 255, 80), Color3.fromRGB(80, 255, 255) },
		Abilities = {
			{ Slot = 1, Name = "Command", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Transform", Skill = "Melee", Requirement = 50 },
			{ Slot = 3, Name = "Revert", Skill = "Melee", Requirement = 50 },
			{ Slot = 4, Name = "Target", Skill = "Melee", Requirement = 150 },
			{ Slot = 5, Name = "Claim", Skill = "Defense", Requirement = 300 },
		},
	},
	Hollow = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(118, 145, 209), Color3.fromRGB(105, 255, 175) },
		Abilities = {
			{ Slot = 1, Name = "Projection", Skill = "Defense", Requirement = 200 },
			{ Slot = 2, Name = "Fade", Skill = "Defense", Requirement = 200 },
			{ Slot = 3, Name = "Negative Hollow", Skill = "Sniper", Requirement = 100, Press = "Charge" },
			{ Slot = 5, Name = "Mini-Hollow", Skill = "Sniper", Requirement = 200 },
		},
	},
	Hot = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 120, 42), Color3.fromRGB(255, 232, 97) },
		Abilities = {
			{ Slot = 1, Name = "Nose Jet", Skill = "Defense", Requirement = 200 },
			{ Slot = 2, Name = "Hot Body", Skill = "Defense", Requirement = 50 },
		},
	},
	Light = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255) },
		Abilities = {
			{ Slot = 1, Name = "Light Sword", Skill = "Sword", Requirement = 100 },
			{ Slot = 2, Name = "Light Blast", Skill = "Sniper", Requirement = 20, Chargeable = true },
			{ Slot = 3, Name = "Yata Mirror", Skill = "Melee", Requirement = 50, Chargeable = true },
			{ Slot = 4, Name = "Light Beam", Skill = "Sniper", Requirement = 250, Press = "Sustained" },
			{ Slot = 5, Name = "Sacred Jewels", Skill = "Defense", Requirement = 300, Press = "Sustained" },
		},
	},
	Love = {
		Rarity = "Uncommon",
		Released = true,
		DefaultColors = { Color3.fromRGB(95, 74, 255), Color3.fromRGB(255, 40, 40) },
		Abilities = {
			{ Slot = 1, Name = "Petrify", Skill = "Defense", Requirement = 25 },
			{ Slot = 2, Name = "Glare", Skill = "Sniper", Requirement = 100, Press = "Sustained" },
			{ Slot = 3, Name = "Pistol Kiss", Skill = "Sniper", Requirement = 150, Chargeable = true, Press = "Sustained" },
			{ Slot = 4, Name = "Beam", Skill = "Sniper", Requirement = 200, Chargeable = true },
			{ Slot = 5, Name = "Slave Arrow", Skill = "Sniper", Requirement = 250, Chargeable = true },
			{ Slot = 6, Name = "Arrow Storm", Skill = "Sniper", Requirement = 300, Chargeable = true },
		},
	},
	Luck = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(90, 90, 255), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Fortune's Purge", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Slot Machine", Skill = "Defense", Requirement = 250 },
			{ Slot = 3, Name = "Dice Roll", Skill = "Sniper", Requirement = 350, Press = "Charge" },
			{ Slot = 4, Name = "Coin throw", Skill = "Melee", Requirement = 450 },
			{ Slot = 5, Name = "Golden Casino", Skill = "Haki", Requirement = 400 },
		},
	},
	Magma = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(83, 138, 255), Color3.fromRGB(83, 0, 255) },
		Abilities = {
			{ Slot = 1, Name = "Great Eruption", Skill = "Melee", Requirement = 50, Chargeable = true },
			{ Slot = 2, Name = "Magma Body", Skill = "Defense", Requirement = 200 },
			{ Slot = 3, Name = "Magma Pool", Skill = "Defense", Requirement = 20 },
			{ Slot = 4, Name = "Magma Flow", Skill = "Sniper", Requirement = 200 },
		},
	},
	More = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(20, 70, 200), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Resize", Skill = "Defense", Requirement = 50 },
			{ Slot = 2, Name = "Resize Other", Skill = "Melee", Requirement = 100 },
			{ Slot = 3, Name = "Restore All", Skill = "Melee", Requirement = 100 },
		},
	},
	Ope = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(166, 255, 0), Color3.fromRGB(160, 20, 40) },
		Abilities = {
			{ Slot = 1, Name = "Room", Skill = "Defense", Requirement = 40, Press = "Charge" },
			{ Slot = 2, Name = "Scalpel", Skill = "Sword", Requirement = 400 },
			{ Slot = 3, Name = "Shambles", Skill = "Defense", Requirement = 30 },
			{ Slot = 4, Name = "Severance", Skill = "Sword", Requirement = 100 },
		},
	},
	Order = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(49, 255, 162), Color3.fromRGB(146, 195, 255) },
		Abilities = {
			{ Slot = 1, Name = "Command Strike", Skill = "Sniper", Requirement = 25 },
		},
	},
	-- No fruit tool exists for it yet (it was still in the works in the place it came from).
	Paw = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(248, 248, 248), Color3.fromRGB(255, 255, 255) },
		Abilities = {
			{ Slot = 1, Name = "Pressure Bubble", Skill = "Sniper", Requirement = 250, Chargeable = true, MaxCharge = 5 },
			{ Slot = 2, Name = "Pad Cannon", Skill = "Sniper", Requirement = 450, Chargeable = true, MaxCharge = 5 },
			{ Slot = 3, Name = "Spatial Repulsion", Skill = "Melee", Requirement = 500, Chargeable = true, MaxCharge = 5 },
			{ Slot = 4, Name = "Ursus Shock", Skill = "Defense", Requirement = 500, Chargeable = true, MaxCharge = 10 },
		},
	},
	Phoenix = {
		Rarity = "UltraRare",
		Released = true,
		DefaultColors = { Color3.fromRGB(98, 255, 103), Color3.fromRGB(56, 255, 199) },
		Abilities = {
			{ Slot = 1, Name = "Fly", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Soar", Skill = "Melee", Requirement = 50 },
			{ Slot = 3, Name = "Phoenix Burst", Skill = "Sniper", Requirement = 200, Chargeable = true },
			{ Slot = 4, Name = "Phoenix Pulse", Skill = "Defense", Requirement = 200 },
		},
	},
	Plasma = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 0) },
		Abilities = {
			{ Slot = 1, Name = "Energize", Skill = "Melee", Requirement = 80 },
			{ Slot = 2, Name = "Plasma Coil", Skill = "Sniper", Requirement = 180 },
			{ Slot = 3, Name = "Plasma Burst", Skill = "Defense", Requirement = 240 },
			{ Slot = 4, Name = "Plasma Cannon", Skill = "Sniper", Requirement = 360, Chargeable = true },
		},
	},
	Quake = {
		Rarity = "UltraRare",
		Released = true,
		DefaultColors = { Color3.fromRGB(0, 255, 255), Color3.fromRGB(135, 168, 227) },
		Abilities = {
			{ Slot = 1, Name = "Quake Punch", Skill = "Melee", Requirement = 100, Chargeable = true, Disabled = true },
			{ Slot = 2, Name = "Tsunami", Skill = "Defense", Requirement = 250, Chargeable = true },
			{ Slot = 3, Name = "Quake Stomp", Skill = "Defense", Requirement = 300, Chargeable = true },
			{ Slot = 4, Name = "Seismic Wave", Skill = "Sniper", Requirement = 400, Chargeable = true },
		},
	},
	Return = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(200, 70, 40), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Return Self", Skill = "Defense", Requirement = 50 },
			{ Slot = 2, Name = "Return Other", Skill = "Melee", Requirement = 100 },
			{ Slot = 3, Name = "Restore All", Skill = "Melee", Requirement = 100 },
		},
	},
	Revive = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(20, 20, 20), Color3.fromRGB(127, 127, 127) },
		Abilities = {},
	},
	Rumble = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 100, 255), Color3.fromRGB(236, 236, 236) },
		Abilities = {
			{ Slot = 1, Name = "Rumble Staff", Skill = "Sword", Requirement = 100 },
			{ Slot = 2, Name = "El Thor", Skill = "Sniper", Requirement = 200, Chargeable = true },
			{ Slot = 3, Name = "Lightning Blitz", Skill = "Melee", Requirement = 50, Chargeable = true },
			{ Slot = 4, Name = "Overload", Skill = "Defense", Requirement = 100, Chargeable = true, Press = "Single" },
		},
	},
	Sand = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(103, 138, 170), Color3.fromRGB(255, 100, 100) },
		Abilities = {
			{ Slot = 1, Name = "Sand Flying", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "Sand Spike", Skill = "Sniper", Requirement = 50 },
			{ Slot = 3, Name = "Sandstorm", Skill = "Defense", Requirement = 100, Chargeable = true },
			{ Slot = 4, Name = "Desert Spada", Skill = "Sword", Requirement = 150 },
		},
	},
	Slash = {
		Rarity = "UltraRare",
		Released = true,
		DefaultColors = { Color3.fromRGB(195, 0, 0), Color3.fromRGB(0, 60, 165) },
		Abilities = {
			{ Slot = 1, Name = "Slash Claws", Skill = "Sword", Requirement = 100 },
			{ Slot = 2, Name = "Slash Dismantle", Skill = "Sword", Requirement = 50, Press = "Charge" },
			{ Slot = 3, Name = "Slash Cleave", Skill = "Sword", Requirement = 300, Press = "Charge" },
			{ Slot = 4, Name = "Slash Frenzy", Skill = "Defense", Requirement = 500 },
		},
	},
	Slip = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(0, 255, 255), Color3.fromRGB(0, 255, 127) },
		Abilities = {
			{ Slot = 1, Name = "Slippery", Skill = "Melee", Requirement = 40 },
		},
	},
	Smelt = {
		Rarity = "Uncommon",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 107, 96), Color3.fromRGB(185, 217, 255) },
		Abilities = {
			{ Slot = 1, Name = "Molten Sword", Skill = "Sword", Requirement = 50 },
			{ Slot = 2, Name = "Silver Body", Skill = "Defense", Requirement = 20 },
			{ Slot = 3, Name = "Spew", Skill = "Defense", Requirement = 50 },
		},
	},
	Smoke = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(36, 43, 66), Color3.fromRGB(21, 82, 83) },
		Abilities = {
			{ Slot = 1, Name = "Fly", Skill = "Melee", Requirement = 100 },
			{ Slot = 2, Name = "White Out", Skill = "Melee", Requirement = 100 },
			{ Slot = 3, Name = "White Fist", Skill = "Melee", Requirement = 50, Press = "Sustained" },
			{ Slot = 4, Name = "Whiteout Burst", Skill = "Defense", Requirement = 300, Press = "Charge" },
		},
	},
	Snow = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(0, 0, 0), Color3.fromRGB(127, 127, 127) },
		Abilities = {
			{ Slot = 1, Name = "Snow Globe", Skill = "Defense", Requirement = 100 },
			{ Slot = 2, Name = "Snow Body", Skill = "Defense", Requirement = 100 },
			{ Slot = 3, Name = "Snow Pellet", Skill = "Sniper", Requirement = 150, Chargeable = true },
			{ Slot = 4, Name = "Snow Angel", Skill = "Defense", Requirement = 200 },
			{ Slot = 5, Name = "Snow Boulder", Skill = "Sniper", Requirement = 100 },
			{ Slot = 6, Name = "Snow Ring", Skill = "Defense", Requirement = 200, Press = "Charge" },
		},
	},
	Spin = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 255, 0), Color3.fromRGB(60, 200, 160) },
		Abilities = {
			{ Slot = 1, Name = "Copter", Skill = "Melee", Requirement = 50 },
			{ Slot = 2, Name = "Raging Top", Skill = "Melee", Requirement = 20 },
			{ Slot = 3, Name = "Spinning Punch", Skill = "Melee", Requirement = 100 },
		},
	},
	Spring = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(140, 20, 60), Color3.fromRGB(90, 200, 190) },
		Abilities = {
			{ Slot = 1, Name = "Jump", Skill = "Melee", Requirement = 20 },
		},
	},
	String = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(255, 180, 51), Color3.fromRGB(165, 255, 105) },
		Abilities = {
			{ Slot = 1, Name = "Release", Skill = "Sniper", Requirement = 50 },
			{ Slot = 2, Name = "Tether", Skill = "Sniper", Requirement = 10, Press = "Charge" },
			{ Slot = 3, Name = "Flapping Thread", Skill = "Sniper", Requirement = 250, Press = "Sustained" },
			{ Slot = 4, Name = "Sky String", Skill = "Sniper", Requirement = 50 },
			{ Slot = 5, Name = "Bird Cage", Skill = "Defense", Requirement = 300, Chargeable = true },
			{ Slot = 6, Name = "God Thread", Skill = "Sniper", Requirement = 400, Chargeable = true },
		},
	},
	Swamp = {
		Rarity = "Unreleased",
		Released = false,
		DefaultColors = { Color3.fromRGB(51, 130, 42), Color3.fromRGB(255, 255, 160) },
		Abilities = {},
	},
	Swim = {
		Rarity = "Common",
		Released = true,
		DefaultColors = { Color3.fromRGB(92, 10, 255), Color3.fromRGB(39, 255, 79) },
		Abilities = {
			{ Slot = 1, Name = "Swim", Skill = "Melee", Requirement = 80 },
			{ Slot = 2, Name = "Dive", Skill = "Melee", Requirement = 100, Press = "Sustained" },
		},
	},
	Vampire = {
		Rarity = "UltraRare",
		Released = true,
		DefaultColors = { Color3.fromRGB(0, 0, 0), Color3.fromRGB(55, 0, 94) },
		Abilities = {
			{ Slot = 1, Name = "Sanguine Vampiris", Skill = "Sword", Requirement = 50, Press = "Charge" },
			{ Slot = 2, Name = "Hypnosis", Skill = "Sniper", Requirement = 300 },
			{ Slot = 3, Name = "Shadow Step", Skill = "Melee", Requirement = 100 },
			{ Slot = 4, Name = "Necromancy", Skill = "Defense", Requirement = 200, Press = "Charge" },
			{ Slot = 5, Name = "Bat Swarm", Skill = "Sniper", Requirement = 200, Chargeable = true },
			{ Slot = 6, Name = "Transform", Skill = "Melee", Requirement = 400 },
		},
	},
	Venom = {
		Rarity = "Rare",
		Released = true,
		DefaultColors = { Color3.fromRGB(43, 106, 42), Color3.fromRGB(161, 12, 12) },
		Abilities = {
			{ Slot = 1, Name = "Poison Breath", Skill = "Sniper", Requirement = 50, Press = "Sustained" },
			{ Slot = 2, Name = "Poison Coat", Skill = "Defense", Requirement = 200 },
			{ Slot = 3, Name = "Venom Hydra", Skill = "Sniper", Requirement = 400, Chargeable = true },
			{ Slot = 4, Name = "Chloro Ball", Skill = "Sniper", Requirement = 400, Chargeable = true },
			{ Slot = 6, Name = "Venom Demon", Skill = "Defense", Requirement = 500 },
		},
	},
}

local FruitConfig = {}

FruitConfig.Fruits = Fruits
FruitConfig.EmptyName = "None"

-- Item affinity score (0-10) to stat multiplier (1.0-2.0).
function FruitConfig.ScoreToMultiplier(score: number): number
	return 1 + math.clamp(math.floor(score), 0, 10) * 0.1
end

-- How the ability uses its key: what its entry says, else "Charge" for a chargeable
-- ability and "Single" for the rest.
function FruitConfig.GetPress(ability: AbilityDefinition): Press
	return ability.Press or (if ability.Chargeable then "Charge" else "Single")
end

--[[
	The ability on a slot of a fruit. A switched-off one (Disabled) is not there: this is
	the one lookup the server's press handler and every client screen go through, so nil
	here is what makes it unusable everywhere at once. `includeDisabled` is for a list that
	wants to name it anyway (and say that it is disabled); never for deciding a use.
]]
function FruitConfig.GetAbility(fruitName: string, slot: number, includeDisabled: boolean?): AbilityDefinition?
	local fruit = Fruits[fruitName]
	if not fruit then
		return nil
	end
	for _, ability in fruit.Abilities do
		if ability.Slot == slot then
			return if ability.Disabled and not includeDisabled then nil else ability
		end
	end
	return nil
end

return table.freeze(FruitConfig)
