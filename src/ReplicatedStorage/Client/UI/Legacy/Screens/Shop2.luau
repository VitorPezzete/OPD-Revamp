--!strict
-- Sword shop (Dagger, Wakizashi, Tachi, Katana): the orange board with the yellow border.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Sword Shop",
	Merchants = { "SwordMerchant" },
	Color = Color3.fromRGB(221, 139, 71),
	Border = Color3.fromRGB(255, 226, 0),
	Icon = "rbxassetid://133293265",
})
