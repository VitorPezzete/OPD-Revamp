--!strict
--[[
	Shared behaviour of the merchant dialogue screens (portrait, text box, one button):
	they close as soon as the character walks away, and the portrait is a square half as
	tall as its panel.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

type Scope = Fusion.Scope<typeof(Fusion)>

local MerchantDialogue = {}

-- Closes the screen when the local character starts moving (or is gone).
function MerchantDialogue.closeOnMove(scope: Scope, close: () -> ())
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		task.defer(close)
		return
	end

	table.insert(scope, humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0 then
			close()
		end
	end))
	table.insert(scope, humanoid.Died:Connect(close))
end

function MerchantDialogue.sizePortrait(scope: Scope, portrait: GuiObject)
	local panel = portrait.Parent
	if not panel or not panel:IsA("GuiObject") then
		return
	end

	local function resize()
		local side = panel.AbsoluteSize.Y / 2
		portrait.Size = UDim2.fromOffset(side, side)
	end
	table.insert(scope, panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
end

function MerchantDialogue.pick(lines: { string }): string
	return lines[math.random(1, #lines)]
end

return MerchantDialogue
