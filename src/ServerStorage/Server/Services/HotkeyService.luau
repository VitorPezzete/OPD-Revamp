--!strict
--[[
	Rebinding of hotkeys (player data Hotkeys.<Action> = { KB, GP, GC }).

	Client API (all return whether the request was accepted):
		HotkeyService:SetHotkey(action, device, keyName)     bind a key ("None" unbinds)
		HotkeyService:SwapHotkeys(actionA, actionB, device)  exchange the keys of two actions
		HotkeyService:ResetHotkeys(device)                   that device back to its defaults

	`device` is a column of the row: "KB" (keyboard), "GP" (gamepad, Advanced layout) or
	"GC" (gamepad, Classic layout); the legacy names "Keyboard" / "Controller" are accepted.
	A request only ever writes the column it names: the keyboard, the Advanced pad and the
	Classic pad are three independent layouts, each saved in the profile with the rest of
	the player's data and so restored on every join, in every place of the experience.

	What may be bound is decided here, never by the client, with the same rules for every
	device (InputConfig): the action must be one of that device, the key one of its
	accepted names and not one the engine keeps in a context of the action, and afterwards
	no two actions that share a context may hold the same key. Binding a key another action
	of the same context holds exchanges the two (InputConfig.PlanBind), so a context never
	holds a duplicate; an exchange that would break a rule is refused whole. The keys in
	force are read through InputConfig.ReadKey, the way the client reads them.

	Legacy problems closed:
	- The remote built ValueObject names from two client strings ("Basic_" .. name) and
	  swapped whatever it found. Actions, devices and key names are whitelists now
	  (InputConfig), and both actions of a swap must share a context.
	- "ResetToDefault" was handled before the argument type checks.
	- The working values of a swap were script-level variables shared by every player's
	  copy of the handler.
	- Nothing limited the rate; each call rewrote replicated values.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local InputConfig = require(ReplicatedStorage.Shared.Configs.InputConfig)
local PlayerData = require(ServerStorage.Server.Classes.PlayerData)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

type PlayerData = PlayerData.PlayerData
type Device = InputConfig.Device

local DEVICE_ALIASES: { [string]: Device } = {
	KB = "KB",
	GP = "GP",
	GC = "GC",
	Keyboard = "KB",
	Controller = "GP",
}

local HotkeyService = Knit.CreateService({
	Name = "HotkeyService",
	Client = {},
})

local DataService

-- A menu changes one binding per click; the burst covers a few in a row.
local rebindLimiter = RateLimiter.new(60, 10)

local function toDevice(value: unknown): Device?
	return if type(value) == "string" then DEVICE_ALIASES[value] else nil
end

local function getData(player: Player): PlayerData?
	if not rebindLimiter:Consume(player) then
		return nil
	end
	return DataService:GetData(player)
end

-- Reads the keys in force for a device straight from the profile.
local function reader(data: PlayerData, device: Device): (action: string) -> string
	local hotkeys = data.Data.Hotkeys :: any
	return function(action: string): string
		local row = hotkeys[action]
		return InputConfig.ReadKey(device, action, if type(row) == "table" then row[device] else nil)
	end
end

-- Writes what a plan decided. Every action and key in it comes from InputConfig, never
-- from the request itself.
local function apply(data: PlayerData, device: Device, changes: { [string]: string })
	local hotkeys = data.Data.Hotkeys :: any
	for action, key in changes do
		if type(hotkeys[action]) ~= "table" then
			-- A profile whose row is missing or broken gets a whole one.
			local row = table.clone(InputConfig.Defaults[action])
			row[device] = key
			data:Set(`Hotkeys.{action}`, row)
		else
			data:Set(`Hotkeys.{action}.{device}`, key)
		end
	end
end

function HotkeyService.Client:SwapHotkeys(player: Player, actionA: unknown, actionB: unknown, deviceName: unknown): boolean
	local data = getData(player)
	local device = toDevice(deviceName)
	if not data or not device then
		return false
	end
	if not InputConfig.IsAction(device, actionA) or not InputConfig.IsAction(device, actionB) then
		return false
	end

	local changes = InputConfig.PlanSwap(device, reader(data, device), actionA :: string, actionB :: string)
	if not changes then
		return false
	end
	apply(data, device, changes)
	return true
end

function HotkeyService.Client:SetHotkey(player: Player, action: unknown, deviceName: unknown, keyName: unknown): boolean
	local data = getData(player)
	local device = toDevice(deviceName)
	if not data or not device or type(keyName) ~= "string" then
		return false
	end
	if not InputConfig.IsAction(device, action) then
		return false
	end

	local changes = InputConfig.PlanBind(device, reader(data, device), action :: string, keyName)
	if not changes then
		return false
	end
	apply(data, device, changes)
	return true
end

function HotkeyService.Client:ResetHotkeys(player: Player, deviceName: unknown): boolean
	local data = getData(player)
	local device = toDevice(deviceName)
	if not data or not device then
		return false
	end

	apply(data, device, InputConfig.PlanReset(device))
	return true
end

function HotkeyService:KnitInit()
	DataService = Knit.GetService("DataService")
end

function HotkeyService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		rebindLimiter:Forget(player)
	end)
end

return HotkeyService
