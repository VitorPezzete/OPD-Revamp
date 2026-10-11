--!strict
--[[
	Merlin the fisherman (Workspace.Map.Merchants.QuestFishMerchant).

	He hands out packages to carry to another merchant of the map. A delivery pays Beri
	(sometimes gems), raises his trust and, the first time, earns the Wood Rod that starts
	the fishing career. At full trust he gives three packages at once and the occasional
	special one. He also sells the Super Rod to proven anglers.

	The client sends three intents: TakePackage, Deliver and BuySuperRod. Which package,
	where it goes and what it pays is server state keyed by the Tool instance; the tool
	only carries its destination as an attribute so the client can draw the arrow.

	Server API
		MerlinService.Delivered (player, packageKind)

	Legacy problems fixed:
	  - every package ran its own `while holding do task.wait()` loop on the server to
	    turn the arrow and test the distance; the arrow is now client-side and the server
	    only validates the delivery when asked;
	  - teleporting between merchants was "detected" by counting how many NPCs the player
	    brushed past and posting to a Discord webhook; a delivery now has to be physically
	    possible in the time since the previous one;
	  - the Super Rod remote had no distance, ownership or requirement check besides the
	    price, so it could be bought (again and again) from anywhere;
	  - the 60 s cooldown ran a per-player loop firing a remote every second for the
	    countdown; the end time is now one attribute the client counts down from.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local World = require(ReplicatedStorage.Shared.Util.World)

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local FishingConfig = require(ReplicatedStorage.Shared.Configs.FishingConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local ToolTemplates = require(ServerStorage.Server.Modules.ToolTemplates)

type PlayerData = PlayerData.PlayerData

type Package = { Owner: Player, Kind: string, Target: Vector3, Timed: boolean }

local MERLIN = FishingConfig.Merlin
local PACKAGE_TEMPLATE = "Package"
local PACKAGE_FOLDER = "Items"
local TARGET_ATTRIBUTE = "DeliveryTarget"
local COOLDOWN_ATTRIBUTE = "MerlinCooldownEnd"
-- Slack on the delivery distance for replication lag of a moving character.
local RANGE_TOLERANCE = 3

local MerlinService = Knit.CreateService({
	Name = "MerlinService",
	Client = {},
})

MerlinService.Delivered = Signal.new() :: Signal.Signal<Player, string>

-- Private servers keep the errand (and the first rod) but pay nothing.
MerlinService.RewardsEnabled = game.PrivateServerOwnerId == 0

local DataService
local CharacterService
local NotifyService
local QuestService
local HakiQuestService
local WeaponUnlockService
local WebhookService

local random = Random.new()
local packages: { [Tool]: Package } = {}
local cooldownEnds: { [Player]: number } = {}
-- Where and when each player last was for certain (took the packages / delivered one).
local anchors: { [Player]: { Position: Vector3, Time: number } } = {}

local takeLimiter = RateLimiter.new(2, 0.5)
local deliverLimiter = RateLimiter.new(3, 1)
local buyLimiter = RateLimiter.new(2, 0.5)

local function getAddress(merchant: Instance): Vector3?
	local torso = merchant:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso.Position
	end
	return nil
end

-- A random merchant to deliver to, and whether it is the (temporary) Haki master.
local function pickDestination(): (Vector3?, boolean)
	local rayleigh = HakiQuestService:GetMerchant()
	local rayleighAddress = rayleigh and getAddress(rayleigh)
	if rayleighAddress and random:NextNumber() < MERLIN.TimedChance then
		return rayleighAddress, true
	end

	local addresses: { Vector3 } = {}
	local folder = World.Merchants()
	for _, merchant in if folder then folder:GetChildren() else {} do
		local address = if merchant.Name ~= MERLIN.Merchant then getAddress(merchant) else nil
		if address then
			table.insert(addresses, address)
		end
	end
	if #addresses == 0 then
		return nil, false
	end

	local address = addresses[random:NextInteger(1, #addresses)]
	return address, address == rayleighAddress
end

local function createPackage(player: Player, special: boolean): boolean
	local target, timed = pickDestination()
	if not target then
		return false
	end

	local kind = if special then "Special Package" else "Package"
	if timed then
		kind = "Timed " .. kind
	end

	local tool = ToolTemplates.Give(player, PACKAGE_TEMPLATE, PACKAGE_FOLDER)
	if not tool then
		return false
	end

	tool.Name = kind
	tool:SetAttribute(TARGET_ATTRIBUTE, target)
	local color = MERLIN.Packages[kind].Color
	local handle = tool:FindFirstChild("Handle")
	if color and handle and handle:IsA("BasePart") then
		handle.Color = color
	end

	packages[tool] = { Owner = player, Kind = kind, Target = target, Timed = timed }
	tool.Destroying:Once(function()
		packages[tool] = nil
	end)
	return true
end

local function holdsPackage(player: Player): boolean
	for _, tool in ToolTemplates.GetCarried(player) do
		if packages[tool] then
			return true
		end
	end
	return false
end

local function payDelivery(player: Player, data: PlayerData, kind: string)
	local reward = MERLIN.Packages[kind]
	local beri = random:NextInteger(reward.Beri.Min, reward.Beri.Max)
	local gems = reward.Gems
	if reward.Item and WeaponUnlockService:Unlock(player, reward.Item) then
		gems = reward.FirstGems or gems
	end

	data:Increment("Economy.Beri", beri)
	if gems > 0 then
		data:Increment("Economy.Gems", gems)
	end
	data:Increment("Fishing.MerlinTrust", 1)
	QuestService:ReduceSamTimer(player, reward.SamSeconds)

	NotifyService:Send(
		player,
		if gems > 0 then `Package delivered: {beri} Beri and {gems} gems!` else `Package delivered: {beri} Beri!`,
		"Success"
	)
end

-- The legendary-mode unlock list can ask for a delivery ("Quest") as its extra task.
local function countLegendaryTask(data: PlayerData)
	local unlock = data.Data.Challenges.LegendaryUnlock
	local extra = type(unlock) == "table" and unlock.Extra
	if type(extra) == "table" and extra.Name == "Quest" and extra.Progress < extra.Limit then
		data:Increment("Challenges.LegendaryUnlock.Extra.Progress", 1, 0, extra.Limit)
	end
end

-- Takes the next batch of packages. Returns false while on cooldown or still carrying one.
function MerlinService.Client:TakePackage(player: Player): boolean
	if not takeLimiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not Proximity.GetMerchant(player, MERLIN.Merchant) then
		return false
	end

	local now = os.clock()
	if now < (cooldownEnds[player] or 0) or holdsPackage(player) then
		return false
	end

	local count = 1
	local special = false
	if data.Data.Fishing.MerlinTrust >= MERLIN.TrustGoal then
		count += MERLIN.TrustedExtraPackages
		special = random:NextNumber() < MERLIN.SpecialChance
	end

	local given = 0
	for _ = 1, count do
		if createPackage(player, false) then
			given += 1
		end
	end
	if special and createPackage(player, true) then
		given += 1
	end
	if given == 0 then
		return false
	end

	cooldownEnds[player] = now + MERLIN.Cooldown
	anchors[player] = { Position = entity.Root.Position, Time = now }
	player:SetAttribute(COOLDOWN_ATTRIBUTE, Workspace:GetServerTimeNow() + MERLIN.Cooldown)
	return true
end

-- Hands over the package held in hand to the merchant the player is standing at.
function MerlinService.Client:Deliver(player: Player): boolean
	if not deliverLimiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	local tool = player.Character and (player.Character :: Model):FindFirstChildOfClass("Tool")
	local package = tool and packages[tool]
	if not data or not entity or entity.Dead or not tool or not package or package.Owner ~= player then
		return false
	end
	if (entity.Root.Position - package.Target).Magnitude > MERLIN.DeliveryRange + RANGE_TOLERANCE then
		return false
	end

	local now = os.clock()
	local anchor = anchors[player]
	if anchor and now - anchor.Time < (anchor.Position - package.Target).Magnitude / MERLIN.MaxTravelSpeed then
		WebhookService:Flag(player, "PackageTravel")
		return false
	end
	anchors[player] = { Position = package.Target, Time = now }

	packages[tool] = nil
	tool:Destroy()

	WeaponUnlockService:Unlock(player, MERLIN.FirstDeliveryItem)
	if MerlinService.RewardsEnabled then
		payDelivery(player, data, package.Kind)
	end
	QuestService:AddQuestObjective(player)
	countLegendaryTask(data)

	MerlinService.Delivered:Fire(player, package.Kind)
	return true
end

function MerlinService.Client:BuySuperRod(player: Player): boolean
	if not buyLimiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	if not data or not Proximity.GetMerchant(player, MERLIN.Merchant) then
		return false
	end

	local offer = MERLIN.SuperRod
	if data.Data.Items[offer.Item] then
		return false
	end
	if not data.Data.Items[offer.RequiredItem] or data.Data.Economy.Fish < offer.FishRequirement then
		NotifyService:Send(player, `Requirement: {offer.RequiredItem} ({offer.FishRequirement} fish caught).`, "Error")
		return false
	end
	if not data:TrySpend("Economy.Beri", offer.Price) then
		NotifyService:Send(player, "Not enough Beri.", "Error")
		return false
	end

	WeaponUnlockService:Unlock(player, offer.Item)
	return true
end

function MerlinService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
	QuestService = Knit.GetService("QuestService")
	HakiQuestService = Knit.GetService("HakiQuestService")
	WeaponUnlockService = Knit.GetService("WeaponUnlockService")
	WebhookService = Knit.GetService("WebhookService")
end

function MerlinService:KnitStart()
	-- Packages addressed to the Haki master are lost when he leaves.
	HakiQuestService.AvailabilityChanged:Connect(function(available: boolean)
		if available then
			return
		end
		for tool, package in table.clone(packages) do
			if package.Timed then
				tool:Destroy()
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		cooldownEnds[player] = nil
		anchors[player] = nil
		takeLimiter:Forget(player)
		deliverLimiter:Forget(player)
		buyLimiter:Forget(player)
	end)
end

return MerlinService
