--!strict
-- Beverages shop, the + drinks (10,000 Beri): the orange board, each drink on its yellow square.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Beverages Shop",
	Merchants = { "BetterDrinkMerchant" },
	Color = Color3.fromRGB(221, 139, 71),
	Border = Color3.fromRGB(255, 226, 0),
	SlotColor = Color3.fromRGB(255, 255, 0),
	SlotTransparency = 0.75,
	Icons = {
		["Cider+"] = "rbxassetid://2310704989",
		["Lemonade+"] = "rbxassetid://2310704995",
		["Juice+"] = "rbxassetid://2310704979",
		["Smoothie+"] = "rbxassetid://2310704985",
	},
})
