--!strict
--[[
	The development place (PlaceConfig.Role "Dev"): a baseplate with no map and no spawn
	screen. Everybody gets a body on the plate as soon as their data is loaded, and again
	a moment after losing it, so there is nothing to click between a death and the next
	try. Their (throw-away) profile is filled in first: maximum levels, every talent and
	weapon, a bounty, kills and money (DevPlaceConfig.Profile), so whatever is being tried
	can be used at once.

	Everywhere else this service is loaded (the main game loads every service) and does
	nothing: it must never fill a real profile or hand out a body. The plate itself is part of the place file
	(Workspace.Map.Baseplate); DevPlaceConfig says where on it people appear.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local PlaceConfig = require(ReplicatedStorage.Shared.Configs.PlaceConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local DevPlaceConfig = require(ServerStorage.Server.Configs.DevPlaceConfig)

local DevPlaceService = Knit.CreateService({
	Name = "DevPlaceService",
	Client = {},
})

local IS_DEV = PlaceConfig.Role == "Dev"

local CharacterService
local DataService
local WeaponUnlockService

-- When each player was first seen without a body, to wait RespawnSeconds before the next one.
local bodilessSince: { [Player]: number } = {}
local random = Random.new()

local function spawnCFrame(): CFrame
	local spread = DevPlaceConfig.SpawnSpread
	local offset = Vector3.new(random:NextNumber(-spread, spread), 0, random:NextNumber(-spread, spread))
	return CFrame.new(DevPlaceConfig.Spawn + offset)
end

local function scan()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		if not CharacterService:IsWaitingToSpawn(player) then
			bodilessSince[player] = nil
			continue
		end
		local since = bodilessSince[player]
		if not since then
			bodilessSince[player] = now
		elseif now - since >= DevPlaceConfig.RespawnSeconds then
			-- Refused while the data is still loading: tried again on the next scan.
			if CharacterService:SpawnAt(player, spawnCFrame()) then
				bodilessSince[player] = nil
			end
		end
	end
end

-- Runs as the profile loads, before the first body: its stats are read from this.
local function fillProfile(player: Player, data: any)
	for path, value in DevPlaceConfig.Profile do
		data:Set(path, value)
	end
	if DevPlaceConfig.MaxPerks then
		for name, perk in data.Data.Expertise.Perks do
			data:Set(`Expertise.Perks.{name}.Value`, perk.Limit)
		end
	end
	if DevPlaceConfig.AllWeapons then
		for weaponName in WeaponConfig.Weapons do
			WeaponUnlockService:Unlock(player, weaponName, true)
		end
	end
end

function DevPlaceService:KnitInit()
	CharacterService = Knit.GetService("CharacterService")
	DataService = Knit.GetService("DataService")
	WeaponUnlockService = Knit.GetService("WeaponUnlockService")
end

function DevPlaceService:KnitStart()
	if not IS_DEV then
		return
	end
	DataService:ObserveData(function(player: Player, data: any)
		local ok, problem = pcall(fillProfile, player, data)
		if not ok then
			warn(`[DevPlaceService] profile of {player.Name} not filled: {problem}`)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		bodilessSince[player] = nil
	end)

	task.spawn(function()
		while true do
			scan()
			task.wait(DevPlaceConfig.ScanSeconds)
		end
	end)
end

return DevPlaceService
