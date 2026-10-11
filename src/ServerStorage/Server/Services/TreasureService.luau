--!strict
--[[
	The compass treasure hunt: Compass, Silver Compass, Golden Compass, Strange Compass and
	??? Strange Compass. (The Burning Compass is CompassService.)

	Compasses are plain Tools handed out by other systems (Sam's tokens, the AFK world,
	world events, the seller, trades, admins). This service makes them work wherever they
	come from: one ChildAdded per player container (Backpack, character) recognises them
	by name the first time a player carries them.

	Flow
	1. First carried: the server decides, once, where the treasure is buried and which box
	   it holds (FruitBoxConfig.Compasses), from the data of that first holder. Only the
	   burial point is published, as an attribute on the Tool, for the holder's needle.
	   The box stays on the server.
	2. The holder follows the needle (TreasureController). Standing on the spot, the client
	   says "I am there", with no arguments.
	3. The server checks that a compass is held, that the character really stands within
	   reach of its treasure and that the trip since the previous dig was possible. The
	   compass is then consumed and the box goes to the backpack (FruitBoxService).

	Legacy problems fixed here:
	- Every compass ran a server loop every 0.1 s while its button was held, moving the
	  needle weld and scanning the parts around the holder for an anti-cheat that ended in
	  an automatic ban sent through a Discord webhook. The needle is now the holder's
	  client's business; the travel check simply refuses the dig (TravelGuard).
	- A tree without a Spawner part broke the tool script (empty random range): the compass
	  never pointed anywhere. Only trees that have one are drawn.
	- The compass was destroyed before the box was known to have somewhere to go.
	- The Strange Compass counted its challenge with a box it had rolled but not given.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)

local TreasureConfig = require(ReplicatedStorage.Shared.Configs.TreasureConfig)
local FruitBoxConfig = require(ServerStorage.Server.Configs.FruitBoxConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local TravelGuard = require(ServerStorage.Server.Classes.TravelGuard)

type Compass = {
	Definition: FruitBoxConfig.Compass,
	Target: Vector3,
	Box: string,
	-- The first holder: the treasure is theirs whoever digs it up.
	FinderId: number,
}

type Tree = { Name: string, Spawners: { Vector3 } }

type Forest = {
	All: { Tree },
	-- Without the trees reserved to Legendary Mode.
	Open: { Tree },
	Lucky: { Tree },
	Fallback: Vector3?,
}

-- Slack on the dig distance: the server sees a running character slightly behind.
local ARRIVAL_TOLERANCE = 8
local NEEDLE = "CompassArrow"
local SECOND_NEEDLE = "CompassArrow2"

local TreasureService = Knit.CreateService({
	Name = "TreasureService",
	Client = {
		-- Client -> server, no arguments: "the compass I am holding has arrived".
		Arrive = Knit.CreateSignal(),
	},
})

local ChallengeService
local CharacterService
local DataService
local FruitBoxService
local FruitService
local MeteoriteService
local NotifyService
local QuestService
local WebhookService

local compasses: { [Tool]: Compass } = {}
-- Connections of each player: "Player", "Spawn", and one per watched container.
local watches: { [Player]: { [string]: RBXScriptConnection } } = {}
local forest: Forest? = nil

local arriveLimiter = RateLimiter.new(2, 0.5)
local travelGuard = TravelGuard.new(FruitBoxConfig.Travel.MinDistance)
local random = Random.new()
local warned: { [string]: boolean } = {}

local function warnOnce(message: string)
	if not warned[message] then
		warned[message] = true
		warn(`[TreasureService] {message}`)
	end
end

-- The burial points of the map, read once: the trees never change.
local function getForest(): Forest
	if forest then
		return forest
	end

	local config = FruitBoxConfig.Trees
	local built: Forest = { All = {}, Open = {}, Lucky = {}, Fallback = nil }
	forest = built

	local folder = World.Find(config.Folder)
	if not folder then
		warnOnce(`Workspace.Map.{config.Folder} not found: tree compasses lead nowhere`)
		return built
	end

	for _, model in folder:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local spawners: { Vector3 } = {}
		for _, child in model:GetChildren() do
			if child.Name == config.SpawnerName and child:IsA("BasePart") then
				table.insert(spawners, child.Position)
			end
		end
		if #spawners == 0 then
			continue
		end

		local tree: Tree = { Name = model.Name, Spawners = spawners }
		table.insert(built.All, tree)
		if model.Name ~= config.LegendaryTree then
			table.insert(built.Open, tree)
		end
		if model.Name == config.LuckyTree then
			table.insert(built.Lucky, tree)
		end
		if model.Name == config.FallbackTree and not built.Fallback then
			built.Fallback = spawners[1]
		end
	end

	if #built.All == 0 then
		warnOnce(`no tree of Workspace.Map.{config.Folder} has a "{config.SpawnerName}" part`)
	end
	return built
end

local function rollTarget(player: Player, data: any, definition: FruitBoxConfig.Compass): Vector3?
	if definition.FixedTarget then
		return definition.FixedTarget
	end

	local luck = FruitBoxConfig.Luck
	local lucky: boolean
	if definition.Luck == "Fruit" then
		lucky = FruitService:HasFruit(player, luck.Fruit)
	else
		local level = math.clamp(math.floor(data.Data.Skills.Expertise.Level), 0, luck.RollMax)
		lucky = random:NextInteger(level, luck.RollMax) >= luck.Threshold
	end

	local trees = getForest()
	local pool: { Tree }
	if lucky then
		pool = trees.Lucky
	elseif definition.LegendaryTrees and not data.Data.Combat.LegendaryMode then
		pool = trees.Open
	else
		pool = trees.All
	end
	if #pool == 0 then
		return trees.Fallback
	end

	local tree = pool[random:NextInteger(1, #pool)]
	return if definition.RandomSpawner then tree.Spawners[random:NextInteger(1, #tree.Spawners)] else tree.Spawners[1]
end

local function rollBox(data: any, definition: FruitBoxConfig.Compass): string?
	local auraOdds = definition.AuraOdds
	if auraOdds and definition.AuraChance > 0 and random:NextNumber() < definition.AuraChance then
		return FruitBoxService:Pick(auraOdds)
	end

	local base = if data.Data.Combat.LegendaryMode and definition.LegendaryOdds
		then definition.LegendaryOdds
		else definition.Odds
	local scale = if definition.ExpertiseScaling then 1 + data.Data.Skills.Expertise.Level / 100 else 1

	local odds: { FruitBoxConfig.Chance } = {}
	local total = 0
	for _, entry in base do
		local chance = entry.Chance * scale
		total += chance
		table.insert(odds, { Box = entry.Box, Chance = chance })
	end
	if definition.Remainder then
		table.insert(odds, { Box = definition.Remainder, Chance = math.max(0, 100 - total) })
	end
	return FruitBoxService:Pick(odds)
end

--[[
	The templates of three compasses carry two needle models, of which the legacy script
	kept one at random. The second is mounted mirrored: the client is told when it stays.
]]
local function keepOneNeedle(tool: Tool)
	local first = tool:FindFirstChild(NEEDLE)
	local second = tool:FindFirstChild(SECOND_NEEDLE)
	if not first or not second then
		return
	end

	if random:NextInteger(1, 2) == 1 then
		second:Destroy()
	else
		first:Destroy()
		second.Name = NEEDLE
		tool:SetAttribute(TreasureConfig.NeedleFlipAttribute, true)
	end
end

local function onCarried(player: Player, child: Instance)
	if not child:IsA("Tool") or compasses[child] then
		return
	end
	local definition = FruitBoxConfig.Compasses[child.Name]
	local data = DataService:GetData(player)
	-- Without data yet the tool is met again when it loads (ObserveData below).
	if not definition or not data then
		return
	end

	local target = rollTarget(player, data, definition)
	local box = rollBox(data, definition)
	if not target or not box then
		warnOnce(`"{child.Name}" has no treasure to lead to`)
		return
	end

	local tool = child
	compasses[tool] = { Definition = definition, Target = target, Box = box, FinderId = player.UserId }
	tool.Destroying:Once(function()
		compasses[tool] = nil
	end)

	keepOneNeedle(tool)
	tool:SetAttribute(TreasureConfig.TargetAttribute, target)
end

local function watchContainer(player: Player, key: string, container: Instance)
	local watch = watches[player]
	if not watch then
		return
	end

	local previous = watch[key]
	if previous then
		previous:Disconnect()
	end
	watch[key] = container.ChildAdded:Connect(function(child: Instance)
		onCarried(player, child)
	end)
	for _, child in container:GetChildren() do
		onCarried(player, child)
	end
end

local function watchPlayer(player: Player)
	if watches[player] then
		return
	end

	local watch: { [string]: RBXScriptConnection } = {}
	watches[player] = watch

	-- A new Backpack and a new character come with every respawn.
	watch.Player = player.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Backpack") then
			watchContainer(player, "Backpack", child)
		end
	end)
	watch.Spawn = player.CharacterAdded:Connect(function(character: Model)
		watchContainer(player, "Character", character)
	end)

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchContainer(player, "Backpack", backpack)
	end
	if player.Character then
		watchContainer(player, "Character", player.Character)
	end
end

local function unwatchPlayer(player: Player)
	local watch = watches[player]
	if watch then
		watches[player] = nil
		for _, connection in watch do
			connection:Disconnect()
		end
	end
end

-- Tools that arrived before the player's data did.
local function rescan(player: Player)
	local function scan(container: Instance?)
		if container then
			for _, child in container:GetChildren() do
				onCarried(player, child)
			end
		end
	end
	scan(player:FindFirstChildOfClass("Backpack"))
	scan(player.Character)
end

local function onArrive(player: Player)
	if not arriveLimiter:Consume(player) then
		return
	end

	local entity = CharacterService:GetPlayerEntity(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not entity or entity.Dead or not entity.Spawned or not backpack then
		return
	end

	-- Held, and really standing on the treasure.
	local tool = entity.Model:FindFirstChildOfClass("Tool")
	local compass = tool and compasses[tool]
	local reach = tool and TreasureConfig.Compasses[tool.Name]
	if not tool or not compass or not reach then
		return
	end
	if (entity.Root.Position - compass.Target).Magnitude > reach.ArrivalRadius + ARRIVAL_TOLERANCE then
		return
	end

	-- Last check: an accepted visit is remembered, so nothing may fail after it.
	if not travelGuard:Visit(player, compass.Target, FruitBoxConfig.Travel.MaxSpeed) then
		warn(`[TreasureService] {player.Name} reached a treasure faster than the trip allows`)
		WebhookService:Flag(player, "CompassTravel")
		NotifyService:Send(player, "The compass has not settled yet. Wait a moment.", "Error")
		return
	end

	local definition = compass.Definition
	local box = FruitBoxService:Give(player, compass.Box, if definition.TracksFinder then compass.FinderId else nil)
	if not box then
		return
	end
	compasses[tool] = nil
	tool:Destroy()

	QuestService:AddQuestObjective(player)
	if definition.Meteorite then
		MeteoriteService:Progress(player, "Compass")
	end
	ChallengeService:Record(player, "CompassTreasure", 1, compass.Box)
end

-- True for a Tool this service has given a treasure to.
function TreasureService:IsCompass(tool: Tool): boolean
	return compasses[tool] ~= nil
end

function TreasureService:KnitInit()
	ChallengeService = Knit.GetService("ChallengeService")
	CharacterService = Knit.GetService("CharacterService")
	DataService = Knit.GetService("DataService")
	FruitBoxService = Knit.GetService("FruitBoxService")
	FruitService = Knit.GetService("FruitService")
	MeteoriteService = Knit.GetService("MeteoriteService")
	NotifyService = Knit.GetService("NotifyService")
	QuestService = Knit.GetService("QuestService")
	WebhookService = Knit.GetService("WebhookService")
end

function TreasureService:KnitStart()
	TreasureService.Client.Arrive:Connect(onArrive)

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	DataService:ObserveData(function(player: Player)
		rescan(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		unwatchPlayer(player)
		arriveLimiter:Forget(player)
		travelGuard:Reset(player)
	end)
end

return TreasureService
