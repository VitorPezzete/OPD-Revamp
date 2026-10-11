--!strict
-- Boat shop of Boat1Merchant. Owners of a Sturdy Rod get the full list, with the Galleon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopWindow = require(ReplicatedStorage.Client.UI.Components.ShopWindow)

return ShopWindow.new({
	-- The five boat shops share the name of their legacy ScreenGui.
	Name = "BoatShop",
	Title = "Boat Shop",
	Merchants = { "Boat1Merchant" },
	Icons = {
		Raft = "rbxassetid://1718412972",
		Boat = "rbxassetid://1718413108",
		Escort = "rbxassetid://1718413068",
		Schooner = "rbxassetid://1718413124",
		Galleon = "rbxassetid://5408552028",
	},
	Variants = {
		{ Items = { "Raft", "Boat", "Escort", "Schooner" }, HiddenWithItem = "Sturdy Rod" },
		{ RequiresItem = "Sturdy Rod" },
	},
})
