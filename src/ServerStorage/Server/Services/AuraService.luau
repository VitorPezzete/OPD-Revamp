--!strict
--[[
	Aura customization: repaints the two effect colours of an eaten fruit for gems.

	Only a fruit that already has an aura (DevilFruits.SlotN.Color is a colour pair, not
	"None") can be repainted, as in the legacy game. The colours are the one thing the
	client chooses; slot, price and the saved format are the server's.

	Legacy remote (UserData.<player>.CustomizeAura): same rules, but it trusted the
	Color3s as sent (NaN / out of range channels went straight into the save string) and
	had no rate limit.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Shared.Packages.Knit)

local AppearanceConfig = require(ReplicatedStorage.Shared.Configs.AppearanceConfig)
local FruitColor = require(ReplicatedStorage.Shared.Util.FruitColor)
local RateLimiter = require(ServerStorage.Server.Classes.RateLimiter)

local AuraService = Knit.CreateService({
	Name = "AuraService",
	Client = {},
})

local DataService
local NotifyService

local NO_COLOR = "None"
local SLOT_COUNT = 2

local limiter = RateLimiter.new(2, 0.5)

-- A Color3 with finite channels clamped to [0, 1], nil for anything else.
local function sanitize(value: unknown): Color3?
	if typeof(value) ~= "Color3" then
		return nil
	end
	local color = value :: Color3
	if color.R ~= color.R or color.G ~= color.G or color.B ~= color.B then
		return nil
	end
	return Color3.new(math.clamp(color.R, 0, 1), math.clamp(color.G, 0, 1), math.clamp(color.B, 0, 1))
end

function AuraService.Client:SetColors(player: Player, slot: unknown, primary: unknown, secondary: unknown): boolean
	local data = DataService:GetData(player)
	local first, second = sanitize(primary), sanitize(secondary)
	if not data or not first or not second or type(slot) ~= "number" then
		return false
	end
	if slot % 1 ~= 0 or slot < 1 or slot > SLOT_COUNT or not limiter:Consume(player) then
		return false
	end

	local path = `DevilFruits.Slot{slot}`
	if data:Get(path .. ".Name") == NO_COLOR or (data:Get(path .. ".Color") or NO_COLOR) == NO_COLOR then
		NotifyService:Send(player, "This fruit has no aura to customize", "Error")
		return false
	end

	local saved = FruitColor.Serialize(first, second)
	if saved == data:Get(path .. ".Color") then
		return false
	end
	if not data:TrySpend(AppearanceConfig.Aura.Currency, AppearanceConfig.Aura.Price) then
		NotifyService:Send(player, "Not enough Gems", "Error")
		return false
	end

	data:Set(path .. ".Color", saved)
	NotifyService:Send(player, "Aura colors changed", "Success")
	return true
end

function AuraService:KnitInit()
	DataService = Knit.GetService("DataService")
	NotifyService = Knit.GetService("NotifyService")
end

function AuraService:KnitStart()
	Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Forget(player)
	end)
end

return AuraService
