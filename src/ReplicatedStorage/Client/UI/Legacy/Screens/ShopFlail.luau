--!strict
-- Timmy's Flail: the green board with one slot and what Timmy says beside it. The old
-- merchant had no script behind it, so the catalogue is flagged Disabled in ShopConfig:
-- the screen opens and the server refuses the purchase.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Timmy",
	Merchants = { "FlailMerchant" },
	Color = Color3.fromRGB(157, 221, 60),
	Border = Color3.fromRGB(255, 106, 0),
	Icon = "rbxassetid://133293265",
	Dialogue = "Hi, I'm Timmy! I like swinging flails at people! I found this one while playing in my backyard. I think it belonged to a squirrel. Wanna buy it?",
})
