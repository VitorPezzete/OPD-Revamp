--!strict
--[[
	Which kind of device each player is playing with, as their client reports it:
	"KeyboardMouse", "Gamepad" or "Touch". Only used for aim assistance (Projectile.Lead):
	a mouse aims by itself, a stick or a thumb gets help.

	A client could claim a gamepad to get the help with a mouse; that gives nothing a
	client could not already do by sending perfect aim points, so it is not checked.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

export type Device = "KeyboardMouse" | "Gamepad" | "Touch"

local DEVICES: { [string]: boolean } = { KeyboardMouse = true, Gamepad = true, Touch = true }
local DEFAULT_DEVICE: Device = "KeyboardMouse"
local AIM_ASSIST_SETTING = "Aim_Assist"

local InputService = Knit.CreateService({
	Name = "InputService",
	Client = {
		-- Client -> server: (device) whenever the device in use changes.
		Device = Knit.CreateSignal(),
	},
})

local SettingsService

local devices: { [Player]: Device } = {}
-- Switching between a pad and the mouse is a few changes a second at most.
local limiter = RateLimiter.new(6, 2)

function InputService:GetDevice(player: Player): Device
	return devices[player] or DEFAULT_DEVICE
end

-- Whether the player's aim gets help: a gamepad or a touch screen, and the setting on.
function InputService:HasAimAssist(player: Player): boolean
	return InputService:GetDevice(player) ~= DEFAULT_DEVICE and SettingsService:Get(player, AIM_ASSIST_SETTING) ~= false
end

function InputService:KnitInit()
	SettingsService = Knit.GetService("SettingsService")
end

function InputService:KnitStart()
	InputService.Client.Device:Connect(function(player: Player, device: unknown)
		if type(device) ~= "string" or not DEVICES[device] or not limiter:Consume(player) then
			return
		end
		devices[player] = device :: Device
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		devices[player] = nil
		limiter:Forget(player)
	end)
end

return InputService
