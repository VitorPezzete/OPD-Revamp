--!strict
--[[
	Weapon ownership gained outside of shops.

	Achievement weapons (InventoryConfig.WeaponUnlocks) are granted the moment their
	counter reaches the goal. The legacy WeaponAchievement script ran one `while
	task.wait(3)` loop per player to find that out; here each counter is observed, so
	nothing runs between changes.

	Server-only API: there is no remote. Shops, boss drops and quests call Unlock.

		WeaponUnlockService:Unlock(player, "Krizma") -> true when newly unlocked
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)
local Signal = require(ReplicatedStorage.Shared.Packages.Signal)

local InventoryConfig = require(ReplicatedStorage.Shared.Configs.InventoryConfig)
local WeaponConfig = require(ReplicatedStorage.Shared.Configs.WeaponConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)

type PlayerData = PlayerData.PlayerData


local WeaponUnlockService = Knit.CreateService({
	Name = "WeaponUnlockService",
	Client = {},
})

-- (player, weaponName) after a weapon becomes owned.
WeaponUnlockService.Unlocked = Signal.new() :: Signal.Signal<Player, string>

local DataService
local NotifyService

-- Counter path -> unlocks watching it.
local unlocksByPath: { [string]: { InventoryConfig.WeaponUnlock } } = {}

function WeaponUnlockService:Owns(player: Player, weaponName: string): boolean
	local data = DataService:GetData(player)
	return data ~= nil and data.Data.Items[weaponName] == true
end

-- Marks a weapon as owned and tells the player. False when unknown or already owned.
function WeaponUnlockService:Unlock(player: Player, weaponName: string, silent: boolean?): boolean
	local data = DataService:GetData(player)
	if not data or not WeaponConfig.Weapons[weaponName] or data.Data.Items[weaponName] == true then
		return false
	end

	data:Set(`Items.{weaponName}`, true)
	WeaponUnlockService.Unlocked:Fire(player, weaponName)
	return true
end

local function checkPath(player: Player, data: PlayerData, path: string)
	local progress = data:Get(path)
	if type(progress) ~= "number" then
		return
	end
	for _, unlock in unlocksByPath[path] do
		if progress >= unlock.Goal then
			WeaponUnlockService:Unlock(player, unlock.Weapon)
		end
	end
end

function WeaponUnlockService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")

	for _, unlock in InventoryConfig.WeaponUnlocks do
		local list = unlocksByPath[unlock.Path]
		if not list then
			list = {}
			unlocksByPath[unlock.Path] = list
		end
		table.insert(list, unlock)
	end
end

function WeaponUnlockService:KnitStart()
	DataService:ObserveData(function(player: Player, data: PlayerData)
		for path in unlocksByPath do
			-- Observers die with the session (PlayerData.Destroy).
			data:Observe(path, function()
				checkPath(player, data, path)
			end)
			checkPath(player, data, path)
		end
	end)
end

return WeaponUnlockService
