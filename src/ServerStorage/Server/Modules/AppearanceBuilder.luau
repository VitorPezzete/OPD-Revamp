--!strict
--[[
	Builds the saved look on an R6 character: clothing parts, face (the Decal
	Head.FakeHead.Face of the StarterCharacter, see CharacterParts), body colours and
	accessories, cloned from ReplicatedStorage.Assets.Models.Customization and welded to
	the limbs inside <character>.Clothes.

	Stateless: every function takes the character and the Appearance table of the player
	data. AppearanceService decides when to call what; a single field change only
	rebuilds the piece it affects (the legacy script rebuilt the entire outfit on every
	arrow click of the menu).

	Pieces are named after what they are (Hair, Shirt, Arm1/Arm2, Leg1/Leg2, Hand1/Hand2,
	Feet1/Feet2, Extra<Slot>); accessories also carry the attribute Accessory = <name>.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AccessoryConfig = require(ReplicatedStorage.Shared.Configs.AccessoryConfig)
local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local AppearanceAssets = require(ReplicatedStorage.Shared.Util.AppearanceAssets)
local CharacterParts = require(ReplicatedStorage.Shared.Util.CharacterParts)
local AccessoryMountConfig = require(ServerStorage.Server.Configs.AccessoryMountConfig)
local OutfitConfig = require(ServerStorage.Server.Configs.OutfitConfig)

export type Appearance = { [string]: any }

type Layout = {
	Limbs: { string },
	Names: { string },
	GetOffset: (piece: BasePart, style: number) -> CFrame,
}

local CLOTHES_FOLDER = "Clothes"
local WHITE = Color3.new(1, 1, 1)

-- Sleeves and trouser legs are shorter than the limb: each style is raised to sit flush
-- with its top. Indexed by style; a style without an entry is centred on the limb.
local ARM_RAISE = { 0.425, 0.225, 0.425, 0.675, 0.225 }
local LEG_RAISE = { 0, 0.275, 0.3375, 0.725, 0.525 }
-- Gloves and shoes hang from the end of the limb, whatever their height.
local EXTREMITY_DROP = 1.1

local SKIN_PROPERTIES = { "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

local function centered(): CFrame
	return CFrame.identity
end

local function atExtremity(piece: BasePart): CFrame
	return CFrame.new(0, -EXTREMITY_DROP + piece.Size.Y / 2, 0)
end

local LAYOUTS: { [string]: Layout } = {
	Hair = { Limbs = { "Head" }, Names = { "Hair" }, GetOffset = centered },
	Torso = {
		Limbs = { "Torso" },
		Names = { "Shirt" },
		GetOffset = function(): CFrame
			return CFrame.Angles(0, math.pi, 0)
		end,
	},
	Arms = {
		Limbs = { "Right Arm", "Left Arm" },
		Names = { "Arm1", "Arm2" },
		GetOffset = function(_piece: BasePart, style: number): CFrame
			return CFrame.new(0, ARM_RAISE[style] or 0, 0)
		end,
	},
	Pants = {
		Limbs = { "Right Leg", "Left Leg" },
		Names = { "Leg1", "Leg2" },
		GetOffset = function(_piece: BasePart, style: number): CFrame
			return CFrame.new(0, LEG_RAISE[style] or 0, 0)
		end,
	},
	Gloves = { Limbs = { "Right Arm", "Left Arm" }, Names = { "Hand1", "Hand2" }, GetOffset = atExtremity },
	Feet = { Limbs = { "Right Leg", "Left Leg" }, Names = { "Feet1", "Feet2" }, GetOffset = atExtremity },
}

local AppearanceBuilder = {}

local function getClothes(character: Model): Instance
	local folder = character:FindFirstChild(CLOTHES_FOLDER)
	if not folder then
		local created = Instance.new("Folder")
		created.Name = CLOTHES_FOLDER
		created.Parent = character
		folder = created
	end
	return folder :: Instance
end

local function clear(folder: Instance, name: string)
	for _, child in folder:GetChildren() do
		if child.Name == name then
			child:Destroy()
		end
	end
end

local function getLimb(character: Model, name: string): BasePart?
	local limb = character:FindFirstChild(name)
	return if limb and limb:IsA("BasePart") then limb else nil
end

-- Clothing must never weigh on, collide with or be hit instead of the character.
local function soften(part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
end

local function fit(piece: BasePart, limb: BasePart, offset: CFrame, name: string, folder: Instance)
	piece.Name = name
	soften(piece)
	for _, descendant in piece:GetDescendants() do
		if descendant:IsA("BasePart") then
			soften(descendant)
		end
	end

	piece.CFrame = limb.CFrame * offset
	piece.Parent = folder

	local weld = Instance.new("Weld")
	weld.Name = "Fit"
	weld.Part0 = limb
	weld.Part1 = piece
	weld.C0 = offset
	weld.Parent = piece
end

local function buildClothing(character: Model, category: string, style: any, colorIndex: any)
	local layout = LAYOUTS[category]
	local config = AppearanceConfig.Categories[category]
	local folder = getClothes(character)
	for _, name in layout.Names do
		clear(folder, name)
	end
	if type(style) ~= "number" then
		return
	end

	local template = AppearanceAssets.GetStyle(config.Folder, style)
	if not template or not template:IsA("BasePart") then
		return
	end
	local color = if type(colorIndex) == "number" then AppearanceAssets.GetColor(colorIndex) else nil

	for index, limbName in layout.Limbs do
		local limb = getLimb(character, limbName)
		if limb then
			local piece = template:Clone()
			if color then
				piece.Color = color
			end
			fit(piece, limb, layout.GetOffset(piece, style), layout.Names[index], folder)
		end
	end
end

local function buildOutfit(character: Model, outfit: OutfitConfig.Outfit)
	local assets = AppearanceAssets.GetFolder(outfit.Folder)
	local folder = getClothes(character)
	for _, entry in outfit.Pieces do
		local template = assets and assets:FindFirstChild(entry.Asset)
		local limb = getLimb(character, entry.Limb)
		if template and template:IsA("BasePart") and limb then
			fit(template:Clone(), limb, entry.Offset, entry.Asset, folder)
		end
	end
	if outfit.Hair then
		buildClothing(character, "Hair", outfit.Hair[1], outfit.Hair[2])
	end
end

-- Whether a name is a clothing category this module builds (Hair, Torso, Arms, ...).
function AppearanceBuilder.IsClothing(category: string): boolean
	return LAYOUTS[category] ~= nil
end

function AppearanceBuilder.ApplyClothing(character: Model, appearance: Appearance, category: string, userId: number)
	-- A personal outfit replaces every clothing category.
	if not LAYOUTS[category] or OutfitConfig[userId] then
		return
	end
	buildClothing(character, category, appearance[category], appearance[category .. "_Color"])
end

function AppearanceBuilder.ApplyFace(character: Model, appearance: Appearance, userId: number)
	local outfit = OutfitConfig[userId]
	local texture: string? = nil
	if outfit and outfit.FaceAsset then
		local assets = AppearanceAssets.GetFolder(outfit.Folder)
		local decal = assets and assets:FindFirstChild(outfit.FaceAsset)
		texture = if decal and decal:IsA("Decal") then decal.Texture else nil
	else
		local index = if outfit and outfit.Face then outfit.Face else appearance.Face
		texture = if type(index) == "number" then AppearanceAssets.GetFaceTexture(index) else nil
	end

	-- The rig's face is Head.FakeHead.Face (StarterCharacter), not Head.face.
	if texture then
		CharacterParts.SetFaceTexture(character, texture)
	end
end

-- Skin dye when the player is using one, the regular skin tone otherwise.
function AppearanceBuilder.ApplySkin(character: Model, appearance: Appearance)
	local color: Color3? = nil
	if appearance.UsingSkinDye == true and type(appearance.SkinDye) == "string" then
		color = AppearanceAssets.GetDye(appearance.SkinDye)
	end
	if not color and type(appearance.SkinColor) == "number" then
		color = AppearanceAssets.GetSkin(appearance.SkinColor)
	end
	if not color then
		return
	end

	local bodyColors: any = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end
	for _, property in SKIN_PROPERTIES do
		bodyColors[property] = color
	end
end

function AppearanceBuilder.ApplyAccessory(character: Model, appearance: Appearance, slot: string)
	local folder = getClothes(character)
	local pieceName = "Extra" .. slot
	clear(folder, pieceName)

	local slots = appearance.ExtraSlots
	local name = if type(slots) == "table" then slots[slot] else nil
	if type(name) ~= "string" or name == "" then
		return
	end

	local mount = AccessoryMountConfig.Mounts[name]
	local template = AppearanceAssets.GetExtra(name)
	if not mount or not template or not template:IsA("BasePart") then
		return
	end

	local colorIndex = slots[slot .. "_Color"]
	local color = (if type(colorIndex) == "number" then AppearanceAssets.GetColor(colorIndex) else nil) or WHITE

	for _, limbName in mount.Limbs do
		local limb = getLimb(character, limbName)
		if not limb then
			continue
		end

		local base = CFrame.identity
		if mount.Attachment then
			local attachment = limb:FindFirstChild(mount.Attachment)
			base = if attachment and attachment:IsA("Attachment")
				then attachment.CFrame
				else AccessoryMountConfig.DefaultAttachments[mount.Attachment] or CFrame.identity
		end

		local piece = template:Clone()
		piece.Color = color
		piece:SetAttribute("Accessory", name)
		-- The shop icon travels with the template; nobody needs it on a character.
		local icon = piece:FindFirstChild("ImageLabel")
		if icon then
			icon:Destroy()
		end
		fit(piece, limb, base * mount.Offset, pieceName, folder)
	end
end

-- The whole look, for a fresh character (or after the whole Appearance table was replaced).
function AppearanceBuilder.ApplyAll(character: Model, appearance: Appearance, userId: number)
	getClothes(character):ClearAllChildren()

	local outfit = OutfitConfig[userId]
	if outfit then
		buildOutfit(character, outfit)
	else
		for category in LAYOUTS do
			buildClothing(character, category, appearance[category], appearance[category .. "_Color"])
		end
	end

	AppearanceBuilder.ApplyFace(character, appearance, userId)
	AppearanceBuilder.ApplySkin(character, appearance)
	for _, slot in AccessoryConfig.Slots do
		AppearanceBuilder.ApplyAccessory(character, appearance, slot)
	end
end

return AppearanceBuilder
