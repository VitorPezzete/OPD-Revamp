--!strict
--[[
	Skin dye roulette for Beri (common colours). Opened by the "Skin Dye" button of the
	menu's shop tab. The roulette itself is shared with SkinDyeShopAll:
	Client.UI.Components.SkinDyeRoulette.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinDyeRoulette = require(ReplicatedStorage.Client.UI.Components.SkinDyeRoulette)

return SkinDyeRoulette({ Name = "SkinDyeShop", Title = "Skin Dye Shop", Rare = false })
