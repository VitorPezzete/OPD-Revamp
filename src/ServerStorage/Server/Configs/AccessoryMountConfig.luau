--!strict
--[[
	Where every accessory (Customization.Extras.<Name>) sits on an R6 character.

	The piece is placed at  limb.CFrame * attachment.CFrame * Offset  (no attachment:
	limb.CFrame * Offset) and welded there. An accessory without a mount cannot be equipped.

	The legacy server had two tables with two conventions; both are folded into Offset:
	- the old one positioned the piece from an avatar attachment of the limb, with a
	  position and XYZ euler angles;
	- the newer one welded piece -> limb with a C0, i.e. the inverse placement, except
	  "Enel Band" which was welded limb -> piece on both arms.
]]

export type Mount = {
	Limbs: { string },
	Attachment: string?,
	Offset: CFrame,
}

local HEAD = { "Head" }
local TORSO = { "Torso" }

local function attached(limbs: { string }, attachment: string, x: number, y: number, z: number, ry: number?, rx: number?, rz: number?): Mount
	return {
		Limbs = limbs,
		Attachment = attachment,
		Offset = CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0)),
	}
end

local function hat(x: number, y: number, z: number, ry: number?, rx: number?): Mount
	return attached(HEAD, "HatAttachment", x, y, z, ry, rx)
end

local function face(x: number, y: number, z: number, ry: number?): Mount
	return attached(HEAD, "FaceFrontAttachment", x, y, z, ry)
end

local function neck(x: number, y: number, z: number, ry: number?): Mount
	return attached(TORSO, "NeckAttachment", x, y, z, ry)
end

local function back(x: number, y: number, z: number, ry: number?, rx: number?, rz: number?): Mount
	return attached(TORSO, "BodyBackAttachment", x, y, z, ry, rx, rz)
end

-- Legacy "piece -> limb" weld: C0 = position * fromOrientation(rx, ry, rz), in degrees.
local function welded(limb: string, x: number, y: number, z: number, rx: number, ry: number, rz: number): Mount
	local c0 = CFrame.new(x, y, z) * CFrame.fromOrientation(math.rad(rx), math.rad(ry), math.rad(rz))
	return { Limbs = { limb }, Offset = c0:Inverse() }
end

local Mounts: { [string]: Mount } = {
	KatakuriScarf = neck(0, 0.16, -0.08),
	Scarf = neck(0, -0.53, 0, 180),
	Bowtie = neck(0, -0.2, -0.56, -90),
	["Ace Necklace"] = neck(0, -0.6, 0, 90),
	Tie = neck(0, -0.85, 0),

	Wings = back(0, 0.3, 0.56, 180),
	EnelDrums = back(0, 2.5, 0.2),
	["Demon Tail"] = back(0, -0.8, 0.8, 0, -180, -180),
	Ducky = attached(TORSO, "BodyFrontAttachment", 0, -0.35, 0.43),

	["Gyro Hat"] = hat(0, 0.1, 0),
	Crown = hat(0, 0.18, 0),
	Halo = hat(0, 0.35, 0),
	Chopper = hat(0, 0.37, 0, -90),
	WanoStrawHat = hat(0, 0, 0),
	["Santa Hat"] = hat(0, 0.55, 0.23, 0, 15),
	MarineCap = hat(0, 0, -0.23),
	Captain = hat(0, 0.2, -0.2),
	["Straw Hat"] = hat(0, 0.4, 0.13),
	["Cipher 0 A"] = hat(0, -0.28, -0.03, 180),
	Tea = hat(0, 0.2, 0),
	["Small Chef"] = hat(0.24, 0.2, 0.22, 20),
	["Egg Head"] = hat(0, -0.3, 0),
	KarasuMask = hat(0, -0.55, -0.31),
	["Cat Ears"] = hat(0, 0.1, 0, -90),
	["Star Tiara"] = hat(0, -0.17, -0.036, -90),
	SpartanHelmet = hat(0, -0.15, 0.2, 180),
	KillerMask = hat(0, -0.5, 0.05),
	["Bunny Ears"] = hat(0, 0.48, 0, -90),
	ShikiWheel = hat(0, 0.63, 0.05),
	["Ram Horns"] = hat(0, -0.3, 0),
	Horns = hat(0, -0.265, 0),
	Pods = hat(0, -0.6, 0),
	TopHat = hat(0, 0.2, 0),

	Blindfold = face(0, 0, 0.95),
	KaidoHorns = face(0, 0.6, 0.35),
	["Summer Glasses"] = face(0, 0.22, 0.428, -90),
	Shades = face(0, 0.18, 0.53, 156),
	["Gothic Glasses"] = face(0, 0.15, 0.05),
	["Streamline Glasses"] = face(0, 0.17, 0.23),
	["Cruiser Glasses"] = face(0, 0.17, 0.45),
	["Classic Glasses"] = face(0, 0.17, 0.43),
	Royalty = face(0, 0.4, 0.13),
	PecloMask = face(0, 0.2, 0.082),
	MonetGlasses = face(0, 0.205, 0.37),
	Hippie = face(0, -0.2, 0.25),
	Cozy = face(0, -0.15, 0.35),
	Biker = face(0, -0.295, 0.3),
	Amish = face(0, -0.08, 0.24),
	Barber = face(0, -0.19, 0.2),
	Full = face(0, -0.155, 0.26),
	Goatee = face(0, -0.38, -0.06),
	Grandfather = face(0, -1.14, 0.24),
	Historian = face(0, -0.23, 0.07),
	Spiky = face(0, -0.2, 0.24),
	Lumberjack = face(0, -0.1, 0.44),
	Moustached = face(0, -0.185, 0.03),
	MrStache = face(0, -0.125, 0.03),
	Wizard = face(0, -1.19, 0),
	["Cipher 0 B"] = face(0, 0.13, 0, -90),
	UssopMask = face(0, 0.48, -0.15),
	Doflamingo = face(0, 0.255, 0.44),
	["Eye Patch"] = face(0, 0.223, 0.591, -90),
	WhitebeardMustache = face(0, -0.025, -0.015),
	Muzzle = face(0, -0.22, 0.6, -90),

	["Enel Band"] = {
		Limbs = { "Right Arm", "Left Arm" },
		Offset = CFrame.new(0, -0.35, 0) * CFrame.fromOrientation(0, math.rad(180), math.rad(90)),
	},
	Clock = welded("Right Arm", 0.575, 0.02, 0.002, 0, 0, -90),
	["King Mask"] = welded("Head", 0, 0.176, -0.062, -90, 180, 0),
	Wheel = welded("Head", -0.026, -1.243, -0.075, -11.25, -135, 0),
	Monocle = welded("Head", -0.611, -0.239, -0.172, 0, -90, 8.149),
	["OPD Tattoo"] = welded("Left Arm", 0.007, -0.525, -0.401, 0, -90, -90),
	["Ruined Crown"] = welded("Head", -0.847, -0.341, -0.019, 90, 90, 0),
	["Cracker Shoulder"] = welded("Right Arm", 0.934, -0.251, 0, 0, 0, 90),
	["Whitebeard Cape"] = welded("Torso", 0, 0.625, -1.1, 25, 0, 0),
	["Marine Cape Red"] = welded("Torso", 0, 0.625, -1.1, 25, 0, 0),
	["Marine Cape Blue"] = welded("Torso", 0, 0.625, -1.1, 25, 0, 0),
	HeadPhone = welded("Head", 0, -0.181, 0.002, -90, -90, 0),
	["Mihawk Hat"] = welded("Head", -0.695, 0.059, 0.04, 0, -171.813, 90),
	["SUPER Glasses"] = welded("Head", -0.013, -0.25, 0.165, 0, 0, 0),
	["Samurai Rope"] = welded("Torso", 1.438, 0.149, 0.126, 0, 0, -90),
}

return table.freeze({
	Mounts = table.freeze(Mounts),

	-- Where the R6 avatar attachments sit on their limb, for a rig that lacks them.
	DefaultAttachments = table.freeze({
		HatAttachment = CFrame.new(0, 0.6, 0),
		FaceFrontAttachment = CFrame.new(0, 0, -0.6),
		NeckAttachment = CFrame.new(0, 1, 0),
		BodyBackAttachment = CFrame.new(0, 0, 0.5),
		BodyFrontAttachment = CFrame.new(0, 0, -0.5),
	} :: { [string]: CFrame }),
})
