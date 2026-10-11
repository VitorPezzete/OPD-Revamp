--!strict
--[[
	Pays Beri / bounty / kill count when a player kills something.
	Purely reactive: it only listens to CombatService.Killed, so a kill can only be
	credited by damage that went through the server pipeline.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local StatConfig = require(ReplicatedStorage.Shared.Configs.StatConfig)
local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RewardConfig = require(ServerStorage.Server.Configs.RewardConfig)

type CharacterEntity = CharacterEntity.CharacterEntity
type PlayerData = PlayerData.PlayerData

local RewardService = Knit.CreateService({
	Name = "RewardService",
	Client = {},
})

-- (killer, victim, reward) after the payout, for quests / challenges / souls.
RewardService.KillRewarded = Signal.new() :: Signal.Signal<Player, CharacterEntity, number>

-- Private servers do not pay rewards.
RewardService.Enabled = game.PrivateServerOwnerId == 0

local DataService
local CombatService

local random = Random.new()

local function hasFruit(data: PlayerData, fruitName: string): boolean
	local fruits = data.Data.DevilFruits
	return fruits.Slot1.Name == fruitName or fruits.Slot2.Name == fruitName
end

local function getPlayerBounty(victim: CharacterEntity, data: PlayerData): number
	local multiplier = 1
	local fruits = data.Data.DevilFruits
	if fruits.Slot1.Name ~= "None" then
		multiplier *= RewardConfig.FruitMultiplier
	end
	if data.Data.Combat.LegendaryMode then
		multiplier *= RewardConfig.LegendaryMultiplier
		if fruits.Slot1.Name ~= "None" and fruits.Slot2.Name ~= "None" then
			multiplier *= RewardConfig.FruitMultiplier
		end
	end
	return math.round(StatConfig.GetTotalLevel(victim.Levels) * multiplier)
end

local function getNpcReward(victim: CharacterEntity): number
	local total = StatConfig.GetTotalLevel(victim.Levels)
	local variation = math.clamp(
		math.floor(total * RewardConfig.NpcVariationFraction),
		RewardConfig.NpcVariationMin,
		RewardConfig.NpcVariationMax
	) * RewardConfig.NpcVariationScale
	return math.round(total + random:NextNumber(variation / 2, variation))
end

local function onKilled(victim: CharacterEntity, attacker: CharacterEntity?)
	if not RewardService.Enabled or not attacker or not attacker.Player then
		return
	end

	local killer = attacker.Player
	local killerData = DataService:GetData(killer)
	if not killerData then
		return
	end

	local reward: number
	if victim.Player then
		local victimData = DataService:GetData(victim.Player)
		if not victimData or table.find(RewardConfig.NoRewardUserIds, victim.Player.UserId) then
			return
		end
		reward = getPlayerBounty(victim, victimData)

		local killHeal = killerData.Data.Expertise.Perks.KillHeal.Value
		if killHeal > 0 then
			attacker:Heal(attacker.MaxHealth * killHeal * RewardConfig.KillHealPerPerkPoint)
		end
	else
		reward = getNpcReward(victim)
		reward *= 1 + killerData.Data.Expertise.Perks.BuffRewards.Value * RewardConfig.RewardsPerPerkPoint

		if string.find(victim.Model.Name, "Zombie", 1, true) then
			killerData:Increment("Combat.ZombiesKilled", 1)
		end
	end

	reward = math.floor(reward)
	local beri = reward
	if hasFruit(killerData, RewardConfig.LuckFruitName) and random:NextNumber() < RewardConfig.LuckChance then
		beri += reward * RewardConfig.LuckBonusMultiplier
	end

	killerData:Increment("Economy.Beri", beri)
	killerData:Increment("Combat.Bounty", reward)
	killerData:Increment("Combat.Kills", 1)

	RewardService.KillRewarded:Fire(killer, victim, reward)
end

function RewardService:KnitInit()
	DataService = Knit.GetService("DataService")
	CombatService = Knit.GetService("CombatService")
end

function RewardService:KnitStart()
	CombatService.Killed:Connect(onKilled)
end

return RewardService
