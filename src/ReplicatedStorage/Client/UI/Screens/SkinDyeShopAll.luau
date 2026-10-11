--!strict
--[[
	Skin dye roulette for gems (every colour). Opened by the "Rare Skin Dye" button of the
	menu's shop tab. The roulette itself is shared with SkinDyeShop:
	Client.UI.Components.SkinDyeRoulette.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkinDyeRoulette = require(ReplicatedStorage.Client.UI.Components.SkinDyeRoulette)

return SkinDyeRoulette({ Name = "SkinDyeShopAll", Title = "Rare Skin Dye Shop", Rare = true })
