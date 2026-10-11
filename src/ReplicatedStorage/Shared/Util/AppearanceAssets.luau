--!strict
--[[
	Lookups in ReplicatedStorage.Assets.Models.Customization (the legacy
	ReplicatedStorage.Clothes, ColorsAll and ColorsCommon): clothing parts, faces,
	palettes, accessories.

	Used by the server (building the look) and by the client (swatches, icons). Every
	lookup is defensive: a missing folder warns once and the caller degrades (a piece is
	skipped, a swatch stays white).

	Expected content, by folder name, either directly under Customization or one level
	down (Customization.Clothes.<Folder>):
		Hair, Torso, Arms, Pants, Gloves, Feet   parts named "1".."N"
		Faces                                    decals named "1".."14"
		Skins, Colors                            parts named "1".."N" (their Color is the swatch)
		Extras                                   accessory parts, each with an ImageLabel (icon)
		ColorsAll, ColorsCommon                  parts named after a BrickColor (skin dyes)
		Hiro, Chizewa, Lyla                      pieces of the personal outfits
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AppearanceAssets = {}

local folders: { [string]: Instance } = {}
local warned: { [string]: boolean } = {}
local brickColorNames: { string }? = nil

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(`[Appearance] {message}`)
	end
end

local function getRoot(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	return models and models:FindFirstChild("Customization")
end

function AppearanceAssets.GetFolder(name: string): Instance?
	local cached = folders[name]
	if cached and cached.Parent then
		return cached
	end

	local root = getRoot()
	local found: Instance? = nil
	if root then
		found = root:FindFirstChild(name)
		if not found then
			local clothes = root:FindFirstChild("Clothes")
			found = clothes and clothes:FindFirstChild(name)
		end
		if not found then
			for _, child in root:GetChildren() do
				found = child:FindFirstChild(name)
				if found then
					break
				end
			end
		end
	end

	if found then
		folders[name] = found
	else
		warnOnce(name, `asset folder "{name}" not found under ReplicatedStorage.Assets.Models.Customization`)
	end
	return found
end

-- A numbered style of a clothing folder.
function AppearanceAssets.GetStyle(folderName: string, index: number): Instance?
	local folder = AppearanceAssets.GetFolder(folderName)
	return folder and folder:FindFirstChild(tostring(index))
end

local function getSwatch(folderName: string, index: number): Color3?
	local swatch = AppearanceAssets.GetStyle(folderName, index)
	return if swatch and swatch:IsA("BasePart") then swatch.Color else nil
end

-- Clothing palette (1..AppearanceConfig.ColorCount).
function AppearanceAssets.GetColor(index: number): Color3?
	return getSwatch("Colors", index)
end

function AppearanceAssets.GetSkin(index: number): Color3?
	return getSwatch("Skins", index)
end

function AppearanceAssets.GetFaceTexture(index: number): string?
	local face = AppearanceAssets.GetStyle("Faces", index)
	return if face and face:IsA("Decal") then face.Texture else nil
end

--[[
	Colour of a skin dye. The dyes are named after BrickColors (the legacy cleanup script
	even resolved them with BrickColor.new), so a missing part falls back to the BrickColor.
]]
function AppearanceAssets.GetDye(name: string): Color3?
	local folder = AppearanceAssets.GetFolder("ColorsAll")
	local swatch = folder and folder:FindFirstChild(name)
	if swatch and swatch:IsA("BasePart") then
		return swatch.Color
	end

	local brickColor = BrickColor.new(name :: any)
	return if brickColor.Name == name then brickColor.Color else nil
end

local function getBrickColorNames(): { string }
	if brickColorNames then
		return brickColorNames
	end
	local names = {}
	for number = 1, 1032 do
		local brickColor = BrickColor.new(number)
		if brickColor.Number == number then
			table.insert(names, brickColor.Name)
		end
	end
	brickColorNames = names
	return names
end

-- Names of the dyes of a pool ("ColorsAll" / "ColorsCommon"). Empty when the pool is unknown.
function AppearanceAssets.GetDyeNames(pool: string): { string }
	local folder = AppearanceAssets.GetFolder(pool)
	if folder then
		local names = {}
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(names, child.Name)
			end
		end
		if #names > 0 then
			return names
		end
	end
	-- The full pool is every BrickColor; the common pool is a hand-picked subset that
	-- only exists as assets.
	return if pool == "ColorsAll" then getBrickColorNames() else {}
end

function AppearanceAssets.GetExtra(name: string): Instance?
	local folder = AppearanceAssets.GetFolder("Extras")
	return folder and folder:FindFirstChild(name)
end

-- Shop / slot icon of an accessory.
function AppearanceAssets.GetExtraIcon(name: string): string?
	local extra = AppearanceAssets.GetExtra(name)
	local icon = extra and extra:FindFirstChild("ImageLabel")
	return if icon and icon:IsA("ImageLabel") and icon.Image ~= "" then icon.Image else nil
end

return AppearanceAssets
