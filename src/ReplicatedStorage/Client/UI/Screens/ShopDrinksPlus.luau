--!strict
-- Beverages shop, the + drinks (10,000 Beri).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	Name = "ShopDrinksPlus",
	Title = "Beverages Shop",
	Merchants = { "BetterDrinkMerchant" },
	Icons = {
		["Cider+"] = "rbxassetid://2310704989",
		["Lemonade+"] = "rbxassetid://2310704995",
		["Juice+"] = "rbxassetid://2310704979",
		["Smoothie+"] = "rbxassetid://2310704985",
	},
})
