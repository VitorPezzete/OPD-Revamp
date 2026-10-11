--!strict
--[[
	Christmas (December): Santa joins the merchants, and the candies he hands out work.

	Santa's own dialogue and remote (start the quest, ask for a candy) belong to the
	merchant system. This module owns what happens around him:
	- the Santa model is in Workspace.Map.Merchants only while the flag is on;
	- "Candy" tools: at Events.XMasLevel 1 each candy is delivered to the merchant of
	  the current task (Events.XMasTask "0".."4") for that task's reward; at level 2 a
	  candy is given to another player, once per player, for gems, and the receiver gets
	  an "Eatable Candy";
	- "Eatable Candy" tools: eaten for experience.

	The candies are plain Tools: whoever creates one only has to name it. Activation is
	heard on the server (Tool.Activated), there is no remote.

	Legacy problem fixed: the delivery target was whatever Humanoid model touched a
	3x2x3 box around the tool handle, matched by model name, so any character model
	named like a merchant counted. Deliveries are now checked against the real
	Workspace.Map.Merchants models, by distance from the player.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local SeasonConfig = require(ServerStorage.Server.Configs.SeasonConfig)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local WorldAssets = require(ServerStorage.Server.Modules.WorldAssets)

local CONFIG = SeasonConfig.Christmas
local STASH_NAME = "SeasonStash"

local Christmas = {}

local random = Random.new()

local function findSanta(): Instance?
	local merchants = Workspace:FindFirstChild(CONFIG.MerchantsFolder)
	local stash = ServerStorage:FindFirstChild(STASH_NAME)
	return (merchants and merchants:FindFirstChild(CONFIG.SantaModel))
		or (stash and stash:FindFirstChild(CONFIG.SantaModel))
		or WorldAssets.Find(CONFIG.SantaModel, "Model", true)
end

local function hideSanta()
	local santa = findSanta()
	if not santa or not santa:IsDescendantOf(Workspace) then
		return
	end
	local stash = ServerStorage:FindFirstChild(STASH_NAME)
	if not stash then
		stash = Instance.new("Folder")
		stash.Name = STASH_NAME
		stash.Parent = ServerStorage
	end
	santa.Parent = stash
end

local function showSanta()
	local santa = findSanta()
	local merchants = Workspace:FindFirstChild(CONFIG.MerchantsFolder)
	if santa and merchants then
		santa.Parent = merchants
	elseif not santa then
		warn(`[Christmas] no "{CONFIG.SantaModel}" model to place with the merchants`)
	end
end

-- Santa stays out of the world for the rest of the year, even if the place saved him in it.
function Christmas.Dormant()
	hideSanta()
end

function Christmas.Start(_context: any): (() -> ())?
	local DataService = Knit.GetService("DataService")
	local CharacterService = Knit.GetService("CharacterService")
	local StatService = Knit.GetService("StatService")
	local NotifyService = Knit.GetService("NotifyService")

	local connections: { any } = {}
	local hooked: { [Tool]: boolean } = setmetatable({} :: any, { __mode = "k" })
	local eating: { [Tool]: boolean } = setmetatable({} :: any, { __mode = "k" })

	local function payTask(player: Player, data: any, candyTask: SeasonConfig.CandyTask)
		if candyTask.Beri then
			data:Increment("Economy.Beri", candyTask.Beri)
		end
		if candyTask.Gems then
			data:Increment("Economy.Gems", candyTask.Gems)
		end
		if candyTask.DFCoins then
			data:Increment("Economy.DFCoins", candyTask.DFCoins)
		end
		for item, count in candyTask.Items or {} do
			WorldAssets.GiveItem(player, item, count)
		end
	end

	local function deliverToMerchant(player: Player, data: any, tool: Tool)
		local index = tonumber(data:Get("Events.XMasTask"))
		local candyTask = index and CONFIG.Tasks[index + 1]
		if not index or not candyTask then
			return
		end

		local nearby = false
		for _, merchantName in candyTask.Merchants do
			if Proximity.GetMerchant(player, merchantName, CONFIG.DeliverRange) then
				nearby = true
				break
			end
		end
		if not nearby then
			return
		end

		tool:Destroy()
		payTask(player, data, candyTask)
		if index + 1 >= #CONFIG.Tasks then
			data:Set("Events.XMasTask", "")
			data:Set("Events.XMasLevel", 2)
			NotifyService:Send(player, "Every candy is delivered! Go back to Santa.", "Success")
		else
			data:Set("Events.XMasTask", tostring(index + 1))
			NotifyService:Send(player, "Candy delivered!", "Success")
		end
	end

	local function giveToPlayer(player: Player, data: any, tool: Tool)
		local entity = CharacterService:GetPlayerEntity(player)
		if not entity then
			return
		end

		local gifted = string.split(data:Get("Events.XMasTask") or "", ",")
		for _, other in Players:GetPlayers() do
			local otherEntity = CharacterService:GetPlayerEntity(other)
			if other == player or not otherEntity or otherEntity.Dead then
				continue
			end
			if (otherEntity.Root.Position - entity.Root.Position).Magnitude > CONFIG.DeliverRange then
				continue
			end
			if table.find(gifted, tostring(other.UserId)) then
				continue
			end

			tool:Destroy()
			data:Set("Events.XMasTask", `{data:Get("Events.XMasTask") or ""}{other.UserId},`)
			data:Increment("Economy.Gems", CONFIG.GiftGems)
			WorldAssets.GiveItem(other, CONFIG.EatableCandyTool)
			NotifyService:Send(other, `{player.DisplayName} gave you a candy!`, "Success")
			return
		end
	end

	local function onCandy(tool: Tool)
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		local data = player and DataService:GetData(player)
		if not player or not data then
			return
		end

		local level = data:Get("Events.XMasLevel")
		if level == 1 then
			deliverToMerchant(player, data, tool)
		elseif level == 2 then
			giveToPlayer(player, data, tool)
		end
	end

	local function onEatableCandy(tool: Tool)
		local player = Players:GetPlayerFromCharacter(tool.Parent)
		if not player or eating[tool] then
			return
		end
		eating[tool] = true

		task.delay(CONFIG.EatSeconds, function()
			if not tool:IsDescendantOf(game) or player.Parent ~= Players then
				return
			end
			tool:Destroy()
			for skill, range in CONFIG.EatExp do
				StatService:AddExp(player, skill :: any, random:NextInteger(range[1], range[2]))
			end
		end)
	end

	local function hookTool(child: Instance)
		if not child:IsA("Tool") or hooked[child] then
			return
		end
		if child.Name == CONFIG.CandyTool then
			hooked[child] = true
			table.insert(connections, child.Activated:Connect(function()
				onCandy(child)
			end))
		elseif child.Name == CONFIG.EatableCandyTool then
			hooked[child] = true
			table.insert(connections, child.Activated:Connect(function()
				onEatableCandy(child)
			end))
		end
	end

	-- A tool can only be activated while equipped, so equipping is the moment to hook it.
	local function watchCharacter(model: Model)
		table.insert(connections, model.ChildAdded:Connect(hookTool))
		for _, child in model:GetChildren() do
			hookTool(child)
		end
	end

	for _, entity in CharacterService:GetEntities() do
		if entity.Player then
			watchCharacter(entity.Model)
		end
	end
	table.insert(connections, CharacterService.EntityAdded:Connect(function(entity)
		if entity.Player then
			watchCharacter(entity.Model)
		end
	end))

	showSanta()

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		hideSanta()
	end
end

return Christmas
