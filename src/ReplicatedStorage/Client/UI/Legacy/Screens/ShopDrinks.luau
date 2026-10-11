--!strict
-- Beverages shop (500 Beri drinks): the orange board, each drink on its yellow square.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Beverages Shop",
	Merchants = { "DrinkMerchant" },
	Color = Color3.fromRGB(221, 139, 71),
	Border = Color3.fromRGB(255, 226, 0),
	SlotColor = Color3.fromRGB(255, 255, 0),
	SlotTransparency = 0.75,
	Icons = {
		Cider = "rbxassetid://2277251451",
		Lemonade = "rbxassetid://2277245876",
		Juice = "rbxassetid://2277245861",
		Smoothie = "rbxassetid://2277245870",
	},
})
