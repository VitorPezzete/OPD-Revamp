--!strict
--[[
	What the interface is right now: which set of screens is mounted (UIConfig.Style) and
	how much the player enlarged it (Settings.UI_Scale).

	UIController writes both from the player's settings; anything that draws interface
	outside a screen (nameplates, the Shave flash) and UI.Util.ScreenScale read them here,
	so they need neither the controller nor the data.

		Interface.Style       Fusion value, "Divine" or "Legacy"
		Interface.UserScale   Fusion value, 1 = the interface's own size
		Interface.getStyle()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)
local UIConfig = require(ReplicatedStorage.Shared.Configs.UIConfig)

local scope = Fusion.scoped(Fusion)

local Interface = {
	Style = scope:Value(UIConfig.Style) :: Fusion.Value<UIConfig.Style>,
	UserScale = scope:Value(1) :: Fusion.Value<number>,
}

function Interface.getStyle(): UIConfig.Style
	return Fusion.peek(Interface.Style)
end

return Interface
