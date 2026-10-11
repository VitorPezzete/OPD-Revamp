--!strict
-- Sword shop (Dagger, Wakizashi, Tachi, Katana).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	Name = "Shop2",
	Title = "Sword Shop",
	Merchants = { "SwordMerchant" },
})
