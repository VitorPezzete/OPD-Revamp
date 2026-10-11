--!strict
-- Sniper shop (Slingshot, Stars, Crossbow, Flintlock).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	Name = "ShopSniper",
	Title = "Sniper Shop",
	Merchants = { "SniperMerchant" },
})
