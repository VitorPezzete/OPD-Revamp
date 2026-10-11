--!strict
-- Blacksmith Krusch (KrizmaMerch): the Krizma sword, one slot on the blue board with his
-- line beside it. The item and its price come from ShopConfig.Merchants.KrizmaMerch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Blacksmith Krusch",
	Merchants = { "KrizmaMerch" },
	Color = Color3.fromRGB(113, 160, 221),
	Icon = "rbxassetid://133293265",
	Dialogue = "This is an experimental design I've been honing for years! I've never seen it fail to destroy its enemy.",
})
