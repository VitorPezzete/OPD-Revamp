--!strict
--[[
	Treasure chests: one per ChestSpawner part of the map, opened by clicking, paying a
	little Beri to the first player who opens it and coming back five minutes later.

	There is no remote. The chest carries one ClickDetector and the server hears the
	click itself, but a click can be fired from anywhere by an exploit, so every open is
	still checked: character spawned and alive, standing next to the chest, and able to
	have travelled from the previous chest (TravelGuard).

	Legacy problems fixed
	- The travel check answered with an automatic ban sent through a Discord webhook whose
	  URL sat in the script. It now only refuses the chest and fires ChestService.Flagged.
	- Private servers displayed a reward that was never paid; they are told so instead.
	- A ClickDetector was created in every part of every chest; one per chest is enough.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local World = require(ReplicatedStorage.Shared.Util.World)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local TravelGuard = require(ServerStorage.Server.Classes.TravelGuard)
local WorldObjectConfig = require(ServerStorage.Server.Configs.WorldObjectConfig)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local WorldAssets = require(ServerStorage.Server.Modules.WorldAssets)

local CONFIG = WorldObjectConfig.Chests

local ChestService = Knit.CreateService({
	Name = "ChestService",
	Client = {},
})

-- (player, beri) after a chest paid out; for quests and challenges.
ChestService.Opened = Signal.new() :: Signal.Signal<Player, number>
-- (player, reason) when an open was refused as impossible; for moderation.
ChestService.Flagged = Signal.new() :: Signal.Signal<Player, string>

local DataService
local CharacterService
local FruitService
local NotifyService
local RewardService
local WebhookService

local template: Model? = nil
local container: Instance
local openLimiter = RateLimiter.new(2, 1)
local travelGuard = TravelGuard.new(CONFIG.MinTravelDistance)
local random = Random.new()
local activeChests = 0

local spawnChest: (cframe: CFrame) -> ()

local function getTravelSpeed(player: Player): number
	for _, fruitName in CONFIG.FastTravelFruits do
		if FruitService:HasFruit(player, fruitName) then
			return CONFIG.FastTravelSpeed
		end
	end
	return CONFIG.MaxTravelSpeed
end

local function canOpen(player: Player, chest: Model): boolean
	local entity = CharacterService:GetPlayerEntity(player)
	if not entity or entity.Dead or not entity.Spawned or not openLimiter:Consume(player) then
		return false
	end
	if not Proximity.IsNear(player, chest, CONFIG.OpenRange) then
		return false
	end
	if not travelGuard:Visit(player, chest:GetPivot().Position, getTravelSpeed(player)) then
		ChestService.Flagged:Fire(player, "ChestTravel")
		return false
	end
	return true
end

local function payOut(player: Player)
	local data = DataService:GetData(player)
	if not data then
		return
	end
	if not RewardService.Enabled then
		NotifyService:Send(player, "Chests are empty in private servers.", "Info")
		return
	end

	local reward = random:NextInteger(CONFIG.RewardMin, CONFIG.RewardMax)
	if FruitService:HasFruit(player, CONFIG.LuckFruit) then
		reward *= CONFIG.LuckMultiplier
	end

	data:Increment("Economy.Beri", reward)
	ChestService.Opened:Fire(player, reward)
end

function spawnChest(cframe: CFrame)
	if not template then
		return
	end

	local chest = template:Clone()
	chest:PivotTo(cframe)

	local detector = Instance.new("ClickDetector")
	detector.MaxActivationDistance = CONFIG.OpenRange
	detector.Parent = chest

	-- Whoever gets here first wins: the flag is set before anything can yield.
	local opened = false
	detector.MouseClick:Connect(function(player: Player)
		if opened or not canOpen(player, chest) then
			return
		end
		opened = true
		activeChests -= 1

		chest:Destroy()
		payOut(player)
		task.delay(CONFIG.RespawnSeconds, spawnChest, cframe)
	end)

	chest.Parent = container
	activeChests += 1
end

local function collectSpawnPoints(): { CFrame }
	local seen: { [Instance]: boolean } = {}
	local points: { CFrame } = {}

	local function add(instance: Instance)
		if instance:IsA("BasePart") and not seen[instance] and instance:IsDescendantOf(Workspace) then
			seen[instance] = true
			table.insert(points, instance.CFrame + Vector3.new(0, CONFIG.SpawnHeightOffset, 0))
		end
	end

	for _, tagged in CollectionService:GetTagged(CONFIG.SpawnerName) do
		add(tagged)
	end
	-- The map's spawners are plain named parts inside the islands; one scan at boot finds them.
	local map = World.Map()
	for _, descendant in if map then map:GetDescendants() else {} do
		if descendant.Name == CONFIG.SpawnerName then
			add(descendant)
		end
	end
	return points
end

-- Chests currently waiting to be opened.
function ChestService:GetCount(): number
	return activeChests
end

-- Call after the game itself teleports a player (events, raids), so the jump is not held against them.
function ChestService:ResetTravel(player: Player)
	travelGuard:Reset(player)
end

function ChestService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	FruitService = Knit.GetService("FruitService")
	NotifyService = Knit.GetService("NotifyService")
	RewardService = Knit.GetService("RewardService")
	WebhookService = Knit.GetService("WebhookService")
end

function ChestService:KnitStart()
	-- The legacy chest module posted its bans to Discord; the flags are reported instead.
	ChestService.Flagged:Connect(function(player: Player, reason: string)
		WebhookService:Flag(player, reason)
	end)

	local found = WorldAssets.Find(CONFIG.Template, "Model")
	template = if found then found :: Model else nil
	if not template then
		return
	end

	-- Spawned chests are runtime instances: Workspace.Instances.Chests, not the map.
	container = World.RuntimeFolder(CONFIG.Container) :: Instance

	for _, cframe in collectSpawnPoints() do
		spawnChest(cframe)
	end

	-- A respawn moves the character legitimately: the next chest is not a "trip".
	CharacterService.EntityAdded:Connect(function(entity)
		if entity.Player then
			travelGuard:Reset(entity.Player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		travelGuard:Reset(player)
		openLimiter:Forget(player)
	end)
end

return ChestService
