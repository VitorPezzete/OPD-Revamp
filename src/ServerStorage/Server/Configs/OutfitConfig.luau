--!strict
--[[
	Personal outfits: three accounts wear a fixed set of pieces instead of the clothing
	they picked (hardcoded UserId branches in the legacy Customize script). Their skin,
	accessories and - unless the outfit says otherwise - face still come from their data.

	Pieces are Customization.<Folder>.<Asset>, placed at limb.CFrame * Offset. The legacy
	welds were piece -> limb with a C0, so Offset is that C0 inverted.
]]

export type Piece = {
	Asset: string,
	Limb: string,
	Offset: CFrame,
}

export type Outfit = {
	Folder: string,
	Pieces: { Piece },
	-- Regular hair worn on top of the pieces ({ style, palette colour }).
	Hair: { number }?,
	-- A decal of the outfit folder used as face...
	FaceAsset: string?,
	-- ...or a fixed regular face. Neither: the player's own face.
	Face: number?,
}

local function piece(asset: string, limb: string, x: number, y: number, z: number, rx: number, ry: number, rz: number): Piece
	local c0 = CFrame.new(x, y, z) * CFrame.fromOrientation(math.rad(rx), math.rad(ry), math.rad(rz))
	return { Asset = asset, Limb = limb, Offset = c0:Inverse() }
end

local Outfits: { [number]: Outfit } = {
	[2294161763] = {
		Folder = "Hiro",
		FaceAsset = "Face",
		Pieces = {
			piece("UtaHair", "Head", 0.3, -0.25, -0.37, 10, 150, 10),
			piece("UtaShirt", "Torso", -0.21, -0.17, 0.035, -90, 90, 0),
			piece("UtaArm1", "Right Arm", 0, 0, 0, 0, 90, 0),
			piece("UtaArm2", "Left Arm", 0, -0.5, 0, 0, 0, 0),
			piece("Utapants1", "Right Leg", -0.04, -0.3, 0, 0, 0, 0),
			piece("Utapants2", "Left Leg", -0.04, -0.3, 0, 0, -180, 0),
			piece("Foot", "Left Leg", 0, 0.85, 0, 0, 0, 0),
			piece("Foot", "Right Leg", 0, 0.85, 0, 0, 0, 0),
		},
	},

	[10656458825] = {
		Folder = "Chizewa",
		Pieces = {
			piece("RukiaArm1", "Right Arm", -0.105, -0.003, -0.105, 90, -90, 0),
			piece("RukiaArm2", "Left Arm", -0.105, -0.008, -0.088, -90, 90, 0),
			piece("RukiaArmDetail1", "Right Arm", 0.578, -0.776, -0.038, 0, 180, -16.039),
			piece("RukiaArmDetail2", "Left Arm", 0.499, -0.791, -0.015, 0, 0, 15),
			piece("RukiaDetailTorso", "Torso", 0.114, 1.046, 0.1, 0, -90, 0),
			piece("RukiaHair", "Head", 0.037, -0.233, -0.031, 0, 0, 0),
			piece("LegLeft", "Left Leg", 0.2, 0.001, 0, -90, 90, 0),
			piece("LegRight", "Right Leg", 0.2, 0.001, 0, -90, 90, 0),
		},
	},

	[451082957] = {
		Folder = "Lyla",
		Hair = { 3, 34 },
		Face = 13,
		Pieces = {
			piece("LylaArm1", "Right Arm", 0.008, 0, -0.171, 90, 0, 0),
			piece("LylaArm2", "Left Arm", 0, 0.009, -0.151, 90, 0, 0),
			piece("LylaSkirt", "Torso", -1.239, -0.054, 0.499, 0, -165, -90),
			piece("LylaTop", "Torso", 0.0075, -0.018, -0.318, 90, 0, 0),
		},
	},
}

return table.freeze(Outfits)
