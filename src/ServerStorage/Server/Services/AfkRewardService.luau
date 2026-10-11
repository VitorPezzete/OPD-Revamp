--!strict
--[[
	The AFK NPC: hands over what the player earned in the AFK world.

	Nothing is earned in this place. The AFK world is a separate place that writes the
	pending rewards into the shared profile (data.AFK_World); this NPC only pays them out,
	so there is no timer here that a client could influence. The request carries no
	arguments: the amounts are read from the saved data.

	Legacy holes closed: the claim remote had no distance check and no limiter, and it
	cloned one tool per pending compass with no cap in a single frame.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)

local MERCHANT_NAME = "AFK_NPC"
local MERCHANT_RANGE = 40
-- Tools handed out per claim; the rest stays pending for the next one.
local MAX_TOOLS_PER_CLAIM = 25

-- data.AFK_World field -> tool given for each unit.
local COMPASSES: { { Field: string, Tool: string } } = {
	{ Field = "Compass", Tool = "Compass" },
	{ Field = "SilverCompass", Tool = "Silver Compass" },
	{ Field = "GoldenCompass", Tool = "Golden Compass" },
}
local CURRENCIES: { { Field: string, Path: string } } = {
	{ Field = "Beri", Path = "Economy.Beri" },
	{ Field = "Gems", Path = "Economy.Gems" },
}

local AfkRewardService = Knit.CreateService({
	Name = "AfkRewardService",
	Client = {},
})

local DataService
local CharacterService
local NotifyService

local claimLimiter = RateLimiter.new(1, 0.5)
local warnedMissing: { [string]: boolean } = {}
local compassGranter: ((player: Player, toolName: string) -> boolean)? = nil

local function pending(value: any): number
	-- math.huge is refused with NaN and negatives: an infinite counter (damaged profile)
	-- minus what was handed out is still infinite, so it paid on every claim for ever.
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then
		return 0
	end
	return math.floor(value)
end

local function findTool(name: string): Tool?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = assets and assets:FindFirstChild("Models")
	local items = models and models:FindFirstChild("Items")
	local backups = ServerStorage:FindFirstChild("Backups")
	local template = (items and items:FindFirstChild(name)) or (backups and backups:FindFirstChild(name))
	if template and template:IsA("Tool") then
		return template
	end

	if not warnedMissing[name] then
		warnedMissing[name] = true
		warn(`[AfkRewardService] Missing tool template: Assets.Models.Items.{name}`)
	end
	return nil
end

local function giveCompass(player: Player, toolName: string): boolean
	if compassGranter then
		return compassGranter(player, toolName)
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local template = findTool(toolName)
	if not backpack or not template then
		return false
	end
	template:Clone().Parent = backpack
	return true
end

-- Lets the service that owns compasses hand them out its own way (the default clones
-- the tool template into the backpack, which is all the legacy NPC did).
function AfkRewardService:SetCompassGranter(granter: (player: Player, toolName: string) -> boolean)
	compassGranter = granter
end

function AfkRewardService.Client:Claim(player: Player): boolean
	if not claimLimiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not data or not entity or entity.Dead or not entity.Spawned then
		return false
	end
	-- A session that is ending refuses every write (PlayerData.Set returns silently): the
	-- tools below would be handed out and their counters left as they were.
	if not data:IsActive() then
		return false
	end
	if not Proximity.GetMerchant(player, MERCHANT_NAME, MERCHANT_RANGE) then
		return false
	end

	local claimed = false

	for _, currency in CURRENCIES do
		local amount = pending(data:Get(`AFK_World.{currency.Field}`))
		local balance = data:Get(currency.Path)
		-- The balance is checked before the pending amount is zeroed: Increment raises on a
		-- balance that is not a number, which used to happen after the zero was written.
		if amount > 0 and type(balance) == "number" and balance == balance then
			data:Set(`AFK_World.{currency.Field}`, 0)
			data:Increment(currency.Path, amount)
			claimed = true
		end
	end

	local toolsLeft = MAX_TOOLS_PER_CLAIM
	for _, compass in COMPASSES do
		local path = `AFK_World.{compass.Field}`
		local owed = pending(data:Get(path))
		local count = math.min(owed, toolsLeft)
		if count <= 0 then
			continue
		end

		-- Taken off the counter before the first tool exists. Counting afterwards relied on
		-- nothing yielding or raising in between: a granter that yields let a second claim
		-- read the same counter, and an error half-way left the tools given and the counter
		-- whole (25 free compasses a claim). What could not be given is put back.
		data:Set(path, owed - count)
		local given = 0
		while given < count do
			local ok, handed = pcall(giveCompass, player, compass.Tool)
			if not ok then
				warn(`[AfkRewardService] giving "{compass.Tool}" to {player.Name} failed: {handed}`)
			end
			if not ok or not handed then
				break
			end
			given += 1
		end
		if given < count then
			-- A compass that cannot be handed out stays pending instead of vanishing.
			data:Set(path, pending(data:Get(path)) + (count - given))
		end
		if given > 0 then
			toolsLeft -= given
			claimed = true
		end
	end

	if claimed then
		NotifyService:Send(player, "AFK rewards claimed!", "Success")
	else
		NotifyService:Send(player, "There is nothing to claim", "Info")
	end
	return claimed
end

function AfkRewardService:KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	NotifyService = Knit.GetService("NotifyService")
end

function AfkRewardService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		claimLimiter:Forget(player)
	end)
end

return AfkRewardService
