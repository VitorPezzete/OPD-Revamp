--!strict
-- Boat shop of Boat3Merchant: the blue board with the boats' pictures. Owners of a Sturdy
-- Rod get the fifth slot, the Galleon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopScreen = require(ReplicatedStorage.Client.UI.Legacy.Components.ShopScreen)

return ShopScreen.new({
	Title = "Boat Shop",
	Merchants = { "Boat3Merchant" },
	Color = Color3.fromRGB(0, 157, 255),
	Border = Color3.fromRGB(0, 251, 255),
	-- The boats were drawn straight on the board.
	SlotTransparency = 1,
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
