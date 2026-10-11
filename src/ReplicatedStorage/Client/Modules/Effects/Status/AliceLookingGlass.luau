--!strict
--[[
	Alice fruit - Looking Glass, on a cursed character (status value: the caster's
	UserId; 5 s). While it lasts the victim cannot damage players (server side).

	Only the victim sees it: the legacy game cloned a ScreenGui called "AliceEffect" into
	their PlayerGui for 5 s. In the legacy place that ScreenGui is empty (no frames at
	all), so nothing was actually drawn; nothing is invented here either. If an
	"AliceEffect" gui is ever added under ReplicatedStorage.Assets.Models.Fruits.Alice
	(or its Power5 folder), it is shown for as long as the curse lasts.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectAssets = require(ReplicatedStorage.Client.Modules.Effects.Util.EffectAssets)

local GUI_NAME = "AliceEffect"

local function noop() end

return function(_character: Model, _value: any, isLocal: boolean): () -> ()
	if not isLocal then
		return noop
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local template = EffectAssets.FindFruit("Alice", GUI_NAME) or EffectAssets.FindFruit("Alice", "Power5", GUI_NAME)
	if not playerGui or not template or not template:IsA("ScreenGui") then
		return noop
	end

	local gui = template:Clone()
	gui.Enabled = true
	gui.Name = "AliceLookingGlass"
	gui.Parent = playerGui

	return function()
		gui:Destroy()
	end
end
