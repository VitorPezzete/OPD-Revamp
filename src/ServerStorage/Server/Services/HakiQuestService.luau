--!strict
--[[
	The Haki master. Silvers Rayleigh appears for a few minutes at a random spot of the
	map; a player strong enough who finds him gets the Haki skill unlocked (level 0 -> 1),
	which is also what enables Observation. Training past that is HakiService's business.

	While he is away the model is parked in ServerStorage, so "is he here" and "is the
	player next to him" are the same check: Proximity.GetMerchant.

	Server API
		HakiQuestService:GetMerchant() -> Model?    the model while he is around
		HakiQuestService.AvailabilityChanged (available)

	Legacy exploit closed: the 1000 total level requirement was only checked by the
	LocalScript of the dialogue, so firing the remote with "III" unlocked Haki for any
	account that happened to be on the server while he was spawned, from anywhere.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local QuestConfig = require(ReplicatedStorage.Shared.Configs.QuestConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local HakiQuestConfig = require(ServerStorage.Server.Configs.HakiQuestConfig)
local Proximity = require(ServerStorage.Server.Modules.Proximity)

local HAKI = QuestConfig.Haki

local HakiQuestService = Knit.CreateService({
	Name = "HakiQuestService",
	Client = {},
})

HakiQuestService.AvailabilityChanged = Signal.new() :: Signal.Signal<boolean>

local DataService
local StatService
local NotifyService

local random = Random.new()
local unlockLimiter = RateLimiter.new(2, 0.5)
local merchant: Model? = nil
local merchantsFolder: Instance? = nil
local available = false
local lastSpawn = 0

local function setAvailable(model: Model, value: boolean)
	if value then
		local index = random:NextInteger(1, #HakiQuestConfig.Spawns)
		if index == lastSpawn then
			index = index % #HakiQuestConfig.Spawns + 1
		end
		lastSpawn = index

		model.Parent = merchantsFolder
		model:PivotTo(HakiQuestConfig.Spawns[index])
	else
		model.Parent = ServerStorage
	end

	available = value
	HakiQuestService.AvailabilityChanged:Fire(value)
end

function HakiQuestService:GetMerchant(): Model?
	return if available then merchant else nil
end

function HakiQuestService.Client:Unlock(player: Player): boolean
	if not unlockLimiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	if not data or not available or not Proximity.GetMerchant(player, HAKI.Merchant) then
		return false
	end

	local skills = data.Data.Skills
	if skills.Haki.Level > 0 then
		return false
	end
	if skills.Melee.Level + skills.Sniper.Level + skills.Defense.Level + skills.Sword.Level < HAKI.TotalLevelRequirement then
		return false
	end

	data:Set("Skills.Haki.Level", HAKI.UnlockedLevel)
	StatService.LevelChanged:Fire(player, "Haki", HAKI.UnlockedLevel)
	NotifyService:Send(player, "You unlocked Haki!", "Success")
	return true
end

function HakiQuestService:KnitInit()
	DataService = Knit.GetService("DataService")
	StatService = Knit.GetService("StatService")
	NotifyService = Knit.GetService("NotifyService")
end

function HakiQuestService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		unlockLimiter:Forget(player)
	end)

	merchantsFolder = World.Merchants()
	local model = merchantsFolder and merchantsFolder:FindFirstChild(HAKI.Merchant)
	if not model or not model:IsA("Model") then
		warn(`[HakiQuestService] Workspace.Map.Merchants.{HAKI.Merchant} not found: the Haki quest is disabled`)
		return
	end

	merchant = model
	setAvailable(model, false)

	task.spawn(function()
		while true do
			task.wait(HakiQuestConfig.AwayDuration)
			setAvailable(model, true)
			task.wait(HakiQuestConfig.ActiveDuration)
			setAvailable(model, false)
		end
	end)
end

return HakiQuestService
