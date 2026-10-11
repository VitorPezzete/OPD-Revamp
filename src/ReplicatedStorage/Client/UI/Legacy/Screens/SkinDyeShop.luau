--!strict
--[[
	Skin dye roulette for Beri (common colours), the blue board. Opened by the "Skin Dye" button of the
	menu's shop tab (Screens/MenuNew/Shop). The roulette itself is shared
	with SkinDyeShopAll: Client.UI.Legacy.Components.SkinDyeSpin.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinDyeSpin = require(ReplicatedStorage.Client.UI.Legacy.Components.SkinDyeSpin)

return SkinDyeSpin({ Rare = false })
