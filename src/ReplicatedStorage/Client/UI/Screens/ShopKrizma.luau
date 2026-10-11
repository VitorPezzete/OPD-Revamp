--!strict
-- Blacksmith Krusch (KrizmaMerch): the Krizma sword. The item and its price come from
-- ShopConfig.Merchants.KrizmaMerch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	Name = "ShopKrizma",
	Title = "Blacksmith Krusch",
	Merchants = { "KrizmaMerch" },
	Speaker = "Krusch",
	Dialogue = "This is an experimental design I've been honing for years! I've never seen it fail to destroy its enemy.",
})
