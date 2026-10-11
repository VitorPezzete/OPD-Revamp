--!strict
--[[
	Hands out carried items (fish, caches, packages, food) as Tools cloned from
	ReplicatedStorage.Assets.Models.

	The exact folder of each template is not fixed, so a name is resolved once by a
	search below Assets.Models (preferring the hinted folder) and cached. A missing
	template is reported once and replaced by a plain handle-less Tool of that name, so
	the gameplay that depends on carrying the item keeps working without its looks.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolTemplates = {}

local cache: { [string]: Tool | false } = {}

local function search(root: Instance?, name: string): Tool?
	if not root then
		return nil
	end
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name and descendant:IsA("Tool") then
			return descendant
		end
	end
	return nil
end

function ToolTemplates.Find(name: string, hint: string?): Tool?
	local cached = cache[name]
	if cached ~= nil then
		return cached or nil
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local found = if hint and models then search(models:FindFirstChild(hint), name) else nil
	found = found or search(models, name)

	if not found then
		warn(`[ToolTemplates] No Tool named "{name}" under ReplicatedStorage.Assets.Models`)
	end
	cache[name] = found or false
	return found
end

-- A fresh, unparented copy (or a bare Tool when the template is missing).
function ToolTemplates.Create(name: string, hint: string?): Tool
	local template = ToolTemplates.Find(name, hint)
	local tool: Tool
	if template then
		tool = template:Clone()
	else
		tool = Instance.new("Tool")
		tool.Name = name
		tool.RequiresHandle = false
	end
	-- Carried items are bound to whoever earned them.
	tool.CanBeDropped = false
	return tool
end

-- Clones the template straight into the player's backpack.
function ToolTemplates.Give(player: Player, name: string, hint: string?): Tool?
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end

	local tool = ToolTemplates.Create(name, hint)
	tool.Parent = backpack
	return tool
end

-- Every Tool the player carries, equipped or not.
function ToolTemplates.GetCarried(player: Player): { Tool }
	local tools: { Tool } = {}
	local function collect(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	collect(player:FindFirstChildOfClass("Backpack"))
	collect(player.Character)
	return tools
end

return ToolTemplates
