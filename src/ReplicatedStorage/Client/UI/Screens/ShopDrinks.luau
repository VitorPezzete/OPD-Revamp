--!strict
-- Beverages shop (500 Beri drinks).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	Name = "ShopDrinks",
	Title = "Beverages Shop",
	Merchants = { "DrinkMerchant" },
	Icons = {
		Cider = "rbxassetid://2277251451",
		Lemonade = "rbxassetid://2277245876",
		Juice = "rbxassetid://2277245861",
		Smoothie = "rbxassetid://2277245870",
	},
})
