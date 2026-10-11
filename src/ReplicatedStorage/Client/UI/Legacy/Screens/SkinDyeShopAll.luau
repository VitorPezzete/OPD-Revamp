--!strict
--[[
	Skin dye roulette for gems (every colour), the red board. Opened by the "Rare Skin Dye" button of the
	menu's shop tab (Screens/MenuNew/Shop). The roulette itself is shared
	with SkinDyeShop: Client.UI.Legacy.Components.SkinDyeSpin.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinDyeSpin = require(ReplicatedStorage.Client.UI.Legacy.Components.SkinDyeSpin)

return SkinDyeSpin({ Rare = true })
