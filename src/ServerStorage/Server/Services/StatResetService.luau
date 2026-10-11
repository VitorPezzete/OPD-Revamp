--!strict
--[[
	The two ways a player wipes their own progress.

	Reset (settings > "Stat Reset" > RESET) - free and irreversible, as in the legacy game:
		Beri, Bounty, Kills, Fish                  -> 0
		Melee / Defense / Sniper / Sword           -> level 1, no exp
		Haki                                       -> level 0, no exp
		both devil fruits (color and affinities)   -> removed
		every owned item (Items)                   -> removed
		loadout                                    -> bare fists
		spawn rotation                             -> 1
	Gems, expertise, accessories, Legendary Mode and everything else are kept.

	Legendary Mode (the altar) - needs all four combat skills at 500, a devil fruit in
	slot 1, 10,000,000 bounty and a fruit item resting on the altar. It consumes that
	item and the eaten fruit, takes the four skills back to level 1 and Beri to 0, and
	unlocks the second fruit slot for good.

	Both requests carry no arguments. Legacy problems fixed: the reset remote had no
	cooldown and relied on the client firing two more remotes afterwards to fix the
	loadout (skip them and the tools of the wiped items stayed in the backpack); the
	Legendary remote indexed player.Character without checking it and did not check
	that the player was anywhere near the altar.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local DataTypes = require(ReplicatedStorage.Shared.Types.DataTypes)
local FruitConfig = require(ReplicatedStorage.Shared.Configs.FruitConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local Proximity = require(ServerStorage.Server.Modules.Proximity)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type PlayerData = PlayerData.PlayerData
type SkillName = DataTypes.SkillName

-- Skill -> level after a full reset.
local RESET_LEVELS: { [SkillName]: number } = {
	Melee = 1,
	Defense = 1,
	Sniper = 1,
	Sword = 1,
	Haki = 0,
}
local RESET_COUNTERS = { "Economy.Beri", "Economy.Fish", "Combat.Bounty", "Combat.Kills" }

local StatResetService = Knit.CreateService({
	Name = "StatResetService",
	Client = {},
})

-- (player) after a full reset / after entering Legendary Mode.
StatResetService.StatsReset = Signal.new() :: Signal.Signal<Player>
StatResetService.LegendaryEntered = Signal.new() :: Signal.Signal<Player>

local AltarService
local DataService
local FruitService
local NotifyService
local StatService
local WeaponService

-- Both actions are one-offs: a slow bucket is enough to stop remote spam.
local limiter = RateLimiter.new(2, 0.1)
local warnedAltar = false

local function setSkill(player: Player, data: PlayerData, skill: SkillName, level: number)
	local previous = data.Data.Skills[skill].Level
	-- Leaves, not the table: stat observers listen on "Skills.<Skill>.Level".
	data:Set(`Skills.{skill}.Exp`, 0)
	data:Set(`Skills.{skill}.Level`, level)
	if previous ~= level then
		StatService.LevelChanged:Fire(player, skill, level)
	end
end

local function removeFruit(player: Player, data: PlayerData, slot: number)
	local fruits = data.Data.DevilFruits
	local fruit = if slot == 1 then fruits.Slot1 else fruits.Slot2
	if fruit.Name ~= FruitConfig.EmptyName then
		FruitService:RemoveFruit(player, slot)
	end
end

-- The fruit item offered on the altar, if any.
local function getAltarOffering(): (Instance?, Tool?)
	-- The altar is AltarService's: it builds the model and knows what lies on it.
	local receptacle = AltarService:GetReceptacle()
	if not receptacle then
		if not warnedAltar then
			warnedAltar = true
			warn("[StatResetService] the altar is not in the world: Legendary Mode is unavailable")
		end
		return nil, nil
	end
	return receptacle, AltarService:GetOffering() or receptacle:FindFirstChildOfClass("Tool")
end

function StatResetService:ResetStats(player: Player): boolean
	local data = DataService:GetData(player)
	if not data then
		return false
	end

	data:Set("Items", {})
	for _, path in RESET_COUNTERS do
		data:Set(path, 0)
	end
	for skill, level in RESET_LEVELS do
		setSkill(player, data, skill, level)
	end
	removeFruit(player, data, 1)
	removeFruit(player, data, 2)
	data:Set("SpawnNumber", 1)
	WeaponService:ResetLoadout(player)

	StatResetService.StatsReset:Fire(player)
	return true
end

function StatResetService:CanEnterLegendary(player: Player): (boolean, string?)
	local data = DataService:GetData(player)
	if not data then
		return false, nil
	end

	local requirements = InventoryConfig.Legendary
	if data.Data.Combat.LegendaryMode then
		return false, "You are already in Legendary Mode"
	end
	for _, skill in requirements.Skills do
		if data.Data.Skills[skill :: SkillName].Level < requirements.SkillLevel then
			return false, `Requires level {requirements.SkillLevel} {skill}`
		end
	end
	if data.Data.DevilFruits.Slot1.Name == FruitConfig.EmptyName then
		return false, "Requires a Devil Fruit"
	end
	if data.Data.Combat.Bounty < requirements.Bounty then
		return false, "Not enough Bounty"
	end
	return true, nil
end

function StatResetService.Client:Reset(player: Player): boolean
	if not limiter:Consume(player) then
		return false
	end
	return StatResetService:ResetStats(player)
end

function StatResetService.Client:EnterLegendaryMode(player: Player): boolean
	if not limiter:Consume(player) then
		return false
	end

	local data = DataService:GetData(player)
	local allowed, reason = StatResetService:CanEnterLegendary(player)
	if not data or not allowed then
		if reason then
			NotifyService:Send(player, reason, "Error")
		end
		return false
	end

	local receptacle, offering = getAltarOffering()
	if not receptacle or not offering or not Proximity.IsNear(player, receptacle, InventoryConfig.Legendary.AltarRange) then
		return false
	end
	offering:Destroy()

	data:Set("Combat.LegendaryMode", true)
	for _, skill in InventoryConfig.Legendary.Skills do
		setSkill(player, data, skill :: SkillName, 1)
	end
	data:Set("Economy.Beri", 0)
	removeFruit(player, data, 1)
	-- Level-gated melee styles are gone with the levels; this puts the fists back.
	WeaponService:Refresh(player)

	StatResetService.LegendaryEntered:Fire(player)
	return true
end

function StatResetService:KnitInit()
	AltarService = Knit.GetService("AltarService")
	DataService = Knit.GetService("DataService")
	FruitService = Knit.GetService("FruitService")
	NotifyService = Knit.GetService("NotifyService")
	StatService = Knit.GetService("StatService")
	WeaponService = Knit.GetService("WeaponService")
end

function StatResetService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
	end)
end

return StatResetService
