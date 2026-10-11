--!strict
-- Sniper shop (Slingshot, Stars, Crossbow, Flintlock): the light blue board.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Sniper Shop",
	Merchants = { "SniperMerchant" },
	Color = Color3.fromRGB(84, 162, 221),
	Border = Color3.fromRGB(163, 160, 255),
	Icon = "rbxassetid://133293265",
})
