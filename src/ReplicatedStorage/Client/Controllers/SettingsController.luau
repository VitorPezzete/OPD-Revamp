--!strict
--[[
	The local player's settings: read them, ask the server to change them, and apply
	the ones that only concern this client.

		SettingsController:Get("Damage_Numbers") -> any       (config default until data loads)
		SettingsController:Observe("Music", function(step) end) -> connection
		SettingsController:Set("Music", 5) / :Cycle("Obs_Mode") / :Cycle("Music", true)
		SettingsController:Reset()                             every setting back to its default

	Applied here: the custom player list (Player_List). The music volume is applied by
	MusicController, Fast Mode by GraphicsController; damage numbers, join
	messages, the observation mode and the bounty column are read by their own systems
	through Get / Observe.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local SettingsConfig = require(ReplicatedStorage.Shared.Configs.SettingsConfig)

local SettingsController = Knit.CreateController({
	Name = "SettingsController",
})

-- ScreenGui of the custom player list (legacy "Core_i7").
local PLAYER_LIST_GUI = "Core_i7"

local DataController
local SettingsService

local localPlayer = Players.LocalPlayer

function SettingsController:Get(name: string): any
	local definition = SettingsConfig.Definitions[name]
	local value = DataController:Get(`Settings.{name}`)
	if value == nil and definition then
		return definition.Default
	end
	return value
end

-- Calls callback with the current value once the data is loaded, then on every change.
function SettingsController:Observe(name: string, callback: (value: any) -> ())
	return DataController:Observe(`Settings.{name}`, function()
		callback(SettingsController:Get(name))
	end)
end

-- Asks the server to store value. Resolves with true when it was accepted.
function SettingsController:Set(name: string, value: any)
	if not SettingsConfig.IsValid(name, value) then
		warn(`[Settings] "{tostring(value)}" is not a valid value for "{name}"`)
	end
	return SettingsService:Set(name, value)
end

-- Asks the server to put the settings back to their defaults (SettingsService.Client:Reset
-- says which ones stay). Resolves with true when it did.
function SettingsController:Reset()
	return SettingsService:Reset()
end

-- Next value of a toggle / cycle / stepped setting; backwards steps the other way.
function SettingsController:Cycle(name: string, backwards: boolean?)
	local current = SettingsController:Get(name)
	local nextValue = if backwards
		then SettingsConfig.Previous(name, current)
		else SettingsConfig.Next(name, current)
	return SettingsController:Set(name, nextValue)
end

local function applyPlayerList()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local list = playerGui and playerGui:FindFirstChild(PLAYER_LIST_GUI)
	if list and list:IsA("ScreenGui") then
		list.Enabled = SettingsController:Get("Player_List") ~= true
	end
end

function SettingsController:KnitInit()
	DataController = Knit.GetController("DataController")
end

function SettingsController:KnitStart()
	SettingsService = Knit.GetService("SettingsService")

	SettingsController:Observe("Player_List", applyPlayerList)

	-- Settings.Sun_Mode and Settings.Fog_Mode are no longer offered: whatever old profiles
	-- saved for them is not applied.

	-- The list is mounted by the UI after this controller starts (and again if it is rebuilt).
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(function(child: Instance)
		if child.Name == PLAYER_LIST_GUI then
			applyPlayerList()
		end
	end)
end

return SettingsController
