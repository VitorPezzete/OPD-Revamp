--!strict
--[[
	Luck fruit - the luck gauge. Status value: luck, 0-100 (set by Passives/Luck for as
	long as the fruit is owned, changed by every Luck ability).

	Only the owner sees it: the bar PlayerGui.DevilFruitIcons.LuckBar.ChargeBar.Bar
	(UI.Layouts.DevilFruitIcons) is filled to the value and shown; removing the status
	(fruit lost) hides it. Nothing happens if that layout is not mounted.

	The effect is restarted on every change of the value, so it only ever sets the bar.
]]
local Players = game:GetService("Players")

local MAX_LUCK = 100

local function noop() end

return function(_character: Model, value: any, isLocal: boolean): () -> ()
	if not isLocal or type(value) ~= "number" then
		return noop
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local icons = playerGui and playerGui:FindFirstChild("DevilFruitIcons")
	local frame = icons and icons:FindFirstChild("LuckBar")
	local chargeBar = frame and frame:FindFirstChild("ChargeBar")
	local bar = chargeBar and chargeBar:FindFirstChild("Bar")
	if not frame or not frame:IsA("GuiObject") or not bar or not bar:IsA("GuiObject") then
		return noop
	end
	local luckFrame: GuiObject = frame

	bar.Size = UDim2.new(math.clamp(value / MAX_LUCK, 0, 1), -2, 1, -2)
	luckFrame.Visible = true

	return function()
		luckFrame.Visible = false
	end
end
