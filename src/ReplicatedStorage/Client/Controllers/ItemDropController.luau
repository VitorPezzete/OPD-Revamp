--!strict
--[[
	Dropping the item in hand.

		ItemDropController:CanDrop(tool) -> boolean   a plain item the drop request accepts
		ItemDropController:Drop() -> boolean          asks the server to drop what is held

	Backspace does it on a keyboard, as the engine's own tools always did (the game's tools
	have CanBeDropped off, so the engine does nothing with the key). A fruit in hand is
	dropped by the same key through its own request (FruitService.Drop). Touch screens and
	gamepads have a prompt with a button instead (the DropGui screen), which calls Drop.

	Nothing but the request is sent: the server drops whatever the character is really
	holding, checks what may be dropped and keeps its own rate limit. The cooldown here
	only saves requests that would be refused.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FruitEconomyConfig = require(ReplicatedStorage.Shared.Configs.FruitEconomyConfig)

local DROP_KEY = Enum.KeyCode.Backspace
local FRUIT_ATTRIBUTE = "FruitItem"

local ItemDropController = Knit.CreateController({
	Name = "ItemDropController",
})

-- Fired with the tool a drop was just requested for.
ItemDropController.Dropped = Signal.new() :: Signal.Signal<Tool>

local FruitSpawnService: any = nil
local FruitService: any = nil

local localPlayer = Players.LocalPlayer
local lastDrop = -math.huge

local function heldTool(): Tool?
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Tool")
end

local function isFruit(tool: Tool): boolean
	return tool:GetAttribute(FRUIT_ATTRIBUTE) ~= nil
end

-- A plain item the drop request accepts. Fruits have their own prompt and request.
function ItemDropController:CanDrop(tool: Tool?): boolean
	return tool ~= nil and not isFruit(tool) and FruitEconomyConfig.IsDroppable(tool.Name)
end

-- Drops the held item, a fruit included. False when nothing was asked of the server.
function ItemDropController:Drop(): boolean
	local tool = heldTool()
	local now = os.clock()
	if not tool or now - lastDrop < FruitEconomyConfig.Drop.CooldownSeconds then
		return false
	end

	if isFruit(tool) then
		-- A place without item actions (the raid) has no such request.
		if not FruitService or not FruitService.Drop then
			return false
		end
		lastDrop = now
		FruitService.Drop:Fire()
	elseif FruitSpawnService and FruitEconomyConfig.IsDroppable(tool.Name) then
		lastDrop = now
		FruitSpawnService.DropTool:Fire()
	else
		return false
	end
	ItemDropController.Dropped:Fire(tool)
	return true
end

function ItemDropController:KnitStart()
	local okSpawn, spawnService = pcall(Knit.GetService, "FruitSpawnService")
	FruitSpawnService = if okSpawn then spawnService else nil
	local okFruit, fruitService = pcall(Knit.GetService, "FruitService")
	FruitService = if okFruit then fruitService else nil

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- Backspace while typing (chat, a text box) erases a letter and nothing else.
		if input.KeyCode ~= DROP_KEY or processed or UserInputService:GetFocusedTextBox() then
			return
		end
		ItemDropController:Drop()
	end)
end

return ItemDropController
