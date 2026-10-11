--!strict
--[[
	What a boss kill is worth: kill counters and drops (BossConfig), rolled on the server
	for the player who landed the killing blow, as the legacy BossDrops script did.

	Purely reactive: it listens to CombatService.Killed, so a kill only counts when the
	damage went through the server pipeline. Other systems hook BossKilled (the Burning
	Compass island opens its way out on it).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local CharacterEntity = require(ServerStorage.Server.Classes.CharacterEntity)
local BossConfig = require(ServerStorage.Server.Configs.BossConfig)

type CharacterEntity = CharacterEntity.CharacterEntity

local BossService = Knit.CreateService({
	Name = "BossService",
	Client = {},
})

-- (killer, bossName, bossEntity) after counters and drops were applied.
BossService.BossKilled = Signal.new() :: Signal.Signal<Player, string, CharacterEntity>

local CombatService
local DataService
local EnemyService
local WeaponUnlockService

local random = Random.new()

local function onKilled(victim: CharacterEntity, attacker: CharacterEntity?)
	if victim.Player or not attacker or not attacker.Player then
		return
	end

	local bossName = EnemyService:GetName(victim)
	local definition = bossName and BossConfig.Bosses[bossName]
	if not bossName or not definition then
		return
	end

	local killer = attacker.Player
	local data = DataService:GetData(killer)
	if not data then
		return
	end

	if definition.KillCounter and type(data:Get(definition.KillCounter)) == "number" then
		data:Increment(definition.KillCounter, 1)
	end

	for _, drop in definition.Drops do
		-- Unlock refuses (and stays silent) when the weapon is already owned.
		if random:NextNumber() < drop.Chance then
			WeaponUnlockService:Unlock(killer, drop.Item)
		end
	end

	BossService.BossKilled:Fire(killer, bossName, victim)
end

function BossService:KnitInit()
	CombatService = Knit.GetService("CombatService")
	DataService = Knit.GetService("DataService")
	EnemyService = Knit.GetService("EnemyService")
	WeaponUnlockService = Knit.GetService("WeaponUnlockService")
end

function BossService:KnitStart()
	CombatService.Killed:Connect(onKilled)
end

return BossService
