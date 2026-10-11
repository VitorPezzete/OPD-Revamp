--!strict
--[[
	The Legendary Hero's quests (LegendaryConfig.Quests):

		FireBoss     hands out the Burning Compass (CompassService), 20 min cooldown
		MarineRaid   opens a raid lobby (RaidService), 1 h cooldown charged at departure
		Endless      opens a raid lobby, 250 gems and 1 h cooldown charged at departure

	The client sends the quest name and nothing else. Requirements, Legendary Mode,
	cooldown and distance to the merchant are all checked here, with the same predicate
	the screen uses to choose the hero's line.

	Entering Legendary Mode (the altar) is StatResetService; this service only reads the flag.

	Legacy problems fixed here (LegendaryHeroServer "Accept"):
	- The remote worked from anywhere on the map.
	- The Fire Boss branch checked neither the bounty nor Legendary Mode, both of which
	  the dialogue required: the hero said "you are not worth my time" and the Accept
	  button under that line handed the compass over anyway. The server now enforces
	  exactly what the dialogue states.
	- The compass check looked for a tool by name in the backpack and character, which
	  errored when the character was missing.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local LegendaryConfig = require(ReplicatedStorage.Shared.Configs.LegendaryConfig)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)
local Proximity = require(ServerStorage.Server.Modules.Proximity)

-- What Accept answers; the screen turns it into the hero's reply.
export type AcceptResult = "Ok" | "Invalid" | "Far" | "Requirements" | "Cooldown" | "Owned" | "Gems" | "Busy"

local MAX_NAME_LENGTH = 32
-- The hero's ClickDetector reaches 32 studs from a part that is not the model's pivot:
-- with the default range a player could open the board and be told to come closer.
local MERCHANT_RANGE = 40

local LegendaryService = Knit.CreateService({
	Name = "LegendaryService",
	Client = {},
})

local CharacterService
local CompassService
local DataService
local NotifyService
local RaidService

local acceptLimiter = RateLimiter.new(3, 0.5)

function LegendaryService.Client:Accept(player: Player, questName: unknown): AcceptResult
	if not acceptLimiter:Consume(player) then
		return "Invalid"
	end
	if type(questName) ~= "string" or #questName > MAX_NAME_LENGTH then
		return "Invalid"
	end

	local quest = LegendaryConfig.Quests[questName]
	local data = DataService:GetData(player)
	local entity = CharacterService:GetPlayerEntity(player)
	if not quest or not data or not entity or entity.Dead or not entity.Spawned then
		return "Invalid"
	end
	if not Proximity.GetMerchant(player, LegendaryConfig.Merchant, MERCHANT_RANGE) then
		return "Far"
	end

	local function get(path: string): any
		return data:Get(path)
	end
	-- The hero only hints at a refusal; the notification says what it was about.
	local cooldownLeft = LegendaryConfig.GetCooldownLeft(questName, get, os.time())
	if cooldownLeft > 0 then
		NotifyService:Send(player, `Available again in {math.ceil(cooldownLeft / 60)} min.`, "Error")
		return "Cooldown"
	end
	if not LegendaryConfig.MeetsRequirements(questName, get) then
		local missing = LegendaryConfig.MissingRequirements(questName, get)
		NotifyService:Send(player, `Missing: {table.concat(missing, ", ")}.`, "Error")
		return "Requirements"
	end

	if quest.Raid then
		if RaidService:IsInLobby(player) then
			return "Busy"
		end
		-- Charged again, for real, when the party leaves; this only avoids opening a
		-- lobby that could never depart.
		if quest.GemCost and data.Data.Economy.Gems < quest.GemCost then
			return "Gems"
		end
		return if RaidService:CreateLobby(player, questName) then "Ok" else "Invalid"
	end

	if CompassService:HasCompass(player) then
		return "Owned"
	end
	if not CompassService:Give(player) then
		return "Invalid"
	end
	data:Set(quest.CooldownPath, os.time() + quest.Cooldown)
	return "Ok"
end

function LegendaryService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	CompassService = Knit.GetService("CompassService")
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
	RaidService = Knit.GetService("RaidService")
end

function LegendaryService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		acceptLimiter:Forget(player)
	end)
end

return LegendaryService
