--!strict
--[[
	Lookup of world / event templates in ReplicatedStorage.Assets.Models, by name and class.

	The legacy place kept them scattered (ServerStorage.Backups, .Halloween, .Events, inside
	scripts). They now live under Assets.Models, mostly in World, Events and Items; the
	preferred folders are searched first and the rest of Models after, so a template that
	was filed elsewhere is still found. A miss warns once and returns nil: callers degrade.

		WorldAssets.Find("TreasureChest", "Model")
		WorldAssets.GiveItem(player, "Compass", 3)   -- Tools cloned into the Backpack
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldAssets = {}

local PREFERRED_FOLDERS = { "World", "Events", "Items" }

local cache: { [string]: Instance | false } = {}

local function getModels(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Models")
end

local function search(root: Instance, name: string, className: string): Instance?
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name and descendant:IsA(className) then
			return descendant
		end
	end
	return nil
end

-- First instance called `name` of class `className` under Assets.Models. Cached.
-- `optional` skips the warning (the caller has another place to look).
function WorldAssets.Find(name: string, className: string, optional: boolean?): Instance?
	local key = `{className}/{name}`
	local cached = cache[key]
	if cached ~= nil then
		return if cached then cached else nil
	end

	local found: Instance? = nil
	local models = getModels()
	if models then
		for _, folderName in PREFERRED_FOLDERS do
			local folder = models:FindFirstChild(folderName)
			found = folder and search(folder, name, className)
			if found then
				break
			end
		end
		found = found or search(models, name, className)
	end

	if not found and not optional then
		warn(`[WorldAssets] no {className} named "{name}" under ReplicatedStorage.Assets.Models`)
	end
	cache[key] = found or false
	return found
end

--[[
	Puts `count` copies of an item Tool in the player's Backpack and returns how many
	were given. This is the one seam between the world systems and the item system:
	when an item service owns item creation, route this function through it.
]]
function WorldAssets.GiveItem(player: Player, itemName: string, count: number?): number
	local template = WorldAssets.Find(itemName, "Tool")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not template or not backpack then
		return 0
	end

	local amount = math.max(1, math.floor(count or 1))
	for _ = 1, amount do
		template:Clone().Parent = backpack
	end
	return amount
end

return WorldAssets
