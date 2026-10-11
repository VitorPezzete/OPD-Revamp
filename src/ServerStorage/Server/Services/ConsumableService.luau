--!strict
--[[
	One-use tools: the drinks sold by DrinkMerchant / BetterDrinkMerchant.

	A drink is a Tool in the backpack, as in the legacy game (not saved: it is lost on
	death or when leaving). Using it needs no remote: Tool.Activated already reaches the
	server, and the server checks who is holding the tool before doing anything.

	Legacy bugs fixed:
	- Cider kept its "used" flag per player in a table that was never cleared, so a player
	  could drink a single Cider per server. Every drink is now single-use per tool.
	- Several drinks could be started at once by swapping tools during the 2 second
	  animation; the Drinking status now gates it.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local ShopConfig = require(ReplicatedStorage.Shared.Configs.ShopConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local ConsumableConfig = require(ServerStorage.Server.Configs.ConsumableConfig)

type PlayerData = PlayerData.PlayerData

local CONSUMABLE_ATTRIBUTE = "Consumable"
-- Replicated: the owner's client plays the drinking animation while it is set.
local USING_STATUS = "Drinking"

local ConsumableService = Knit.CreateService({
	Name = "ConsumableService",
	Client = {},
})

-- (player, consumableName) once the effect has been applied.
ConsumableService.Consumed = Signal.new() :: Signal.Signal<Player, string>

local CharacterService
local StatService

local warnedMissing: { [string]: boolean } = {}

-- Assets.Models.Items.<Name>; the other two are where the legacy place kept them.
local function findTemplate(name: string): Tool?
	local models = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Models")
	local items = models and models:FindFirstChild("Items")
	local candidates: { Instance? } = {
		items,
		items and items:FindFirstChild("Juices"),
		ServerStorage:FindFirstChild("Juices"),
	}
	for _, folder in candidates do
		local template = folder and folder:FindFirstChild(name)
		if template and template:IsA("Tool") then
			return template
		end
	end

	if not warnedMissing[name] then
		warnedMissing[name] = true
		warn(`[ConsumableService] Missing tool template: Assets.Models.Items.{name}`)
	end
	return nil
end

local function countIn(container: Instance?): number
	local count = 0
	if container then
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute(CONSUMABLE_ATTRIBUTE) ~= nil then
				count += 1
			end
		end
	end
	return count
end

local function countCarried(player: Player): number
	return countIn(player:FindFirstChildOfClass("Backpack")) + countIn(player.Character)
end

-- True when the drink was started (the tool is then spent).
local function use(tool: Tool, name: string): boolean
	local definition = ConsumableConfig.Consumables[name]
	local character = tool.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	local entity = player and CharacterService:GetPlayerEntity(player)
	if not definition or not player or not entity or entity.Model ~= character then
		return false
	end
	if entity.Dead or not entity.Spawned or entity:HasStatus(USING_STATUS) then
		return false
	end

	entity:SetStatus(USING_STATUS, true, ConsumableConfig.UseSeconds, true)
	task.delay(ConsumableConfig.UseSeconds, function()
		-- Dying or leaving destroys the tool: the drink is lost without effect, as before.
		if not tool:IsDescendantOf(game) or entity.Dead or not player:IsDescendantOf(Players) then
			return
		end
		tool:Destroy()
		StatService:AddExp(player, definition.Skill, definition.Exp, true)
		ConsumableService.Consumed:Fire(player, name)
	end)
	return true
end

function ConsumableService:IsAvailable(name: string): boolean
	return ConsumableConfig.Consumables[name] ~= nil and findTemplate(name) ~= nil
end

-- Puts one consumable in the player's backpack. False when it cannot be handed out.
function ConsumableService:Give(player: Player, name: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local template = if ConsumableConfig.Consumables[name] then findTemplate(name) else nil
	if not backpack or not template then
		return false
	end

	local tool = template:Clone()
	tool:SetAttribute(CONSUMABLE_ATTRIBUTE, name)
	-- The connection dies with the tool. A tool is used a single time.
	local spent = false
	tool.Activated:Connect(function()
		if not spent then
			spent = use(tool, name)
		end
	end)
	tool.Parent = backpack
	return true
end

function ConsumableService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	StatService = Knit.GetService("StatService")

	Knit.GetService("ShopService"):RegisterGrant("Consumable", {
		Check = function(player: Player, _data: PlayerData, item: ShopConfig.Item): (boolean, string?)
			if not ConsumableService:IsAvailable(item.Name) then
				return false, "This item is unavailable"
			end
			if countCarried(player) >= ConsumableConfig.MaxCarried then
				return false, "You can't carry any more"
			end
			return true, nil
		end,
		Give = function(player: Player, _data: PlayerData, item: ShopConfig.Item): boolean
			return ConsumableService:Give(player, item.Name)
		end,
	})
end

return ConsumableService
