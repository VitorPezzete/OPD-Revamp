--!strict
-- Timmy's Flail. The catalogue is flagged Disabled in ShopConfig (the legacy merchant had
-- no script behind it): the screen opens, the Buy button is greyed and the server refuses.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	Name = "ShopFlail",
	Title = "Timmy",
	Merchants = { "FlailMerchant" },
	Speaker = "Timmy",
	Dialogue = "Hi, I'm Timmy! I like swinging flails at people! I found this one while playing in my backyard. I think it belonged to a squirrel. Wanna buy it?",
})
