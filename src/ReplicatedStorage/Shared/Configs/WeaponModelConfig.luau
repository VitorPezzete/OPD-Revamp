--!strict
--[[
	What a weapon looks like in the hand: which parts of
	ReplicatedStorage.Assets.Models.Weapons.SwordModels / UtilityModels are shown while its
	Tool is held, on which limb of the R6 character, and where.

	A mounted part sits at

		part.CFrame = limb.CFrame * Offset        (a Weld limb -> part with C0 = Offset)

	and everything else in the model follows it through the model's own joints.
	Server.Modules.WeaponModels builds them; a weapon without an entry stays as its Tool is.

	These Tools have no Handle, and must not get one: with a Handle the stock Animate
	script holds the right arm straight out ("toolnone"), and every offset here was made
	for an arm hanging at the side. The legacy tool scripts cloned the model and welded
	it to the limb themselves; the offsets are theirs (the Equipped handler of each script
	under ServerStorage.Backups.Weapons.Sword / Utility):
	- most set the part's CFrame to arm.CFrame * X and added a WeldConstraint: Offset = X;
	- Ice Spear and Lollipop used a Motor6D arm -> part with C0 = X: Offset = X;
	- Shirayuki and Yamato welded an inner part ("default", the hilt) with C0 = X: that
	  part is the Anchor. Their sheath, held in the left hand, was welded by a part that
	  sits exactly on the sheath, so it needs none.

	Nothing was ever shown for a weapon that was put away: Katana2, Tachi2, Wakizashi2 and
	Dagger2 in SwordModels are the first held models of those swords, used by no script.
	The Flail had no model at all.
]]

export type Limb = "Right Arm" | "Left Arm"

export type Mount = {
	-- Folder under Assets.Models.Weapons, and the part in it.
	Folder: "SwordModels" | "UtilityModels",
	Model: string,
	Limb: Limb,
	Offset: CFrame,
	-- Descendant of the model the weld holds instead of the model's own part.
	Anchor: string?,
	-- Descendants of the model that are not shown.
	Without: { string }?,
}

local RIGHT_ARM: Limb = "Right Arm"
local LEFT_ARM: Limb = "Left Arm"

-- Legacy notation: CFrame.new(x, y, z) * CFrame.Angles(rx, ry, rz), angles in degrees.
local function at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

local function sword(model: string, offset: CFrame, limb: Limb?, anchor: string?): Mount
	return table.freeze({
		Folder = "SwordModels" :: "SwordModels",
		Model = model,
		Limb = limb or RIGHT_ARM,
		Offset = offset,
		Anchor = anchor,
	})
end

local function utility(model: string, offset: CFrame): Mount
	return table.freeze({ Folder = "UtilityModels" :: "UtilityModels", Model = model, Limb = RIGHT_ARM, Offset = offset })
end

-- The models built around their grip only need to be put in the hand.
local HAND = at(0, -1, 0)
local ROD = at(0, -1, 0, 0, -180, 0)
local TWIN_BLADE = at(0, -0.95, -1.35, 9.998, 0, 0)
local KRIZMA = sword("Krizma", at(-1.1, -1.1, -1.3, 0, 90, 115))

local Weapons: { [string]: { Mount } } = {
	["Aqua Staff"] = { sword("Aqua Staff", HAND) },
	Bisento = { sword("Bisento", at(0, -0.8, -1.4, 90, 0, 90)) },
	["Candy Cane Kogatana"] = { sword("Candy Kogatana", at(0, -1, -0.8, 0, 0, 90)) },
	Dagger = { sword("Dagger", at(0, -1, -0.9, -90, 90, 0)) },
	["Divine Axe"] = { sword("Divine Axe", at(0, -1.26, -2.42, 180, -90, 180)) },
	["Divine Kogatana"] = { sword("Divine Kogatana", HAND) },
	["Divine Yoru"] = { sword("Divine Yoru", HAND) },
	["Golden Fish"] = { sword("Golden Fish", at(0, -0.95, -2.6, 90, -360, 180)) },
	["Ice Dagger"] = { sword("Ice Dagger", at(-1.1, -2, -1.3, 0, 90, 180)) },
	["Ice Spear"] = {
		sword("Ice Spear", CFrame.new(-0.8, 4.7, 2.8) * CFrame.fromOrientation(math.rad(52), math.rad(-115), math.rad(-4))),
	},
	-- One blade per hand, mirrored by the arms themselves.
	["Kanshou and Bakuya"] = { sword("Kanshou", TWIN_BLADE), sword("Bakuya", TWIN_BLADE, LEFT_ARM) },
	Katana = { sword("Katana", at(0, -1, -2.95, -90, 90, 0)) },
	Kogatana = { sword("Kogatana", HAND) },
	Krizma = { KRIZMA },
	["Lightning Sword"] = { sword("Lightning Sword", HAND) },
	Lollipop = { sword("Pirulito", at(0, -1, -1.5, 0, 90, -90)) },
	Masamune = { sword("Masamune", HAND) },
	["Meteorite Sword"] = { sword("Meteorite Sword", at(0, -1, -1.4, 180, 180, -180)) },
	-- Legacy pulled the sheath off with the left hand and dropped it a second after the
	-- dagger was drawn: what stays in the hand is the bare blade.
	Roger = {
		table.freeze({
			Folder = "SwordModels" :: "SwordModels",
			Model = "Roger",
			Limb = RIGHT_ARM,
			Offset = at(0, -1.15, -0.75, -10, -90, 0),
			Without = table.freeze({ "AceDaggerSheath" }),
		}),
	},
	["Scissors Blade"] = { sword("Scissors Blade", at(0, -1.1, -1.5, 181, 90, 90)) },
	Shirayuki = {
		-- Legacy C0: CFrame.new(0, -1, 0, 0.99, 0, 0.01, 0.015, -0.70, -0.75, -0.012, -0.75, 0.70),
		-- a mirror (determinant -1) that no weld can hold as a rotation. With its Y axis
		-- turned back it is the 47 degree tilt that lays the diagonal mesh flat, blade
		-- forward like every other sword.
		sword(
			"RukiaSword",
			CFrame.new(0, -1, 0, 0.99, 0, 0.01, 0.015, 0.70, -0.75, -0.012, 0.75, 0.70):Orthonormalize(),
			RIGHT_ARM,
			"default"
		),
		sword("Sheath", CFrame.new(0, -1, 0.15, -1, 0, 0, 0, 0.7, -0.71, 0, -0.71, -0.7):Orthonormalize(), LEFT_ARM),
	},
	Tachi = { sword("Tachi", at(0, -1, -2.25, -90, 90, 0)) },
	-- Its script cloned the Krizma: it never had a model of its own.
	["Ultra Great Sword"] = { KRIZMA },
	Wakizashi = { sword("Wakizashi", at(0, -1, -1.67, -90, 90, 0)) },
	Yamato = {
		sword("YamatoSword", at(0, -1, -0.1, 40, 90, 0), RIGHT_ARM, "default"),
		sword(
			"SheathYamato",
			CFrame.new(0.0473175049, -1.09, 0.584228516, 0, 0, -1, 0.40248999, 0.915424407, 0, 0.915424347, -0.40248999, 0)
				:Orthonormalize(),
			LEFT_ARM
		),
	},
	Yoru = { sword("Yoru", HAND) },

	["Sturdy Rod"] = { utility("SturdyRod", ROD) },
	["Super Rod"] = { utility("SuperRod", ROD) },
	["Wood Rod"] = { utility("WoodRod", ROD) },
	["Zombie Head"] = { utility("Zombie Head", at(0, -1.3, 0)) },
}

for _, mounts in Weapons do
	table.freeze(mounts)
end

return table.freeze({
	Weapons = table.freeze(Weapons),
})
