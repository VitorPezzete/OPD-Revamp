--!strict
--[[
	What the side menu (Screens.MenuNew) takes of the screen, for the HUD pieces that share
	the left edge with it (the mission tracker).

	On a touch screen the menu column sits at mid-height of the left edge (the bottom-left
	corner is the thumbstick's), which is where the HUD used to have room. The menu
	publishes its footprint here and those pieces place themselves from it, so neither
	screen has to know the other, and a place without the menu leaves the defaults.

		MenuSpace.MidLeft   true where the column sits at mid-height (touch screens)
		MenuSpace.Edge      Fusion value: design pixels from the left of the screen to where
		                    the free space starts, right of the column and its handle, gap
		                    included. 0 with no column and no handle
		MenuSpace.Busy      Fusion value: a tab window or one of the menu's separate screens
		                    is open
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local rootScope = Fusion.scoped(Fusion)

local MenuSpace = {}

MenuSpace.MidLeft = UserInputService.TouchEnabled
MenuSpace.Edge = rootScope:Value(0)
MenuSpace.Busy = rootScope:Value(false)

return MenuSpace
