--!strict
--[[
	Luck fruit - Slot Machine: shows the three reels to the player who spun them.
	params: { Symbols: { string } }   (plus Caster, Colors)

	The effect reaches every nearby client; only the caster's own shows anything. The
	reels are the Icon1..Icon3 images of PlayerGui.DevilFruitIcons.Luck
	(UI.Layouts.DevilFruitIcons): they appear a quarter of a second apart and hide 1.5 s
	after the last one, unless another spin replaced them meanwhile. Nothing happens if
	that layout is not mounted.
]]
local Players = game:GetService("Players")

local ICONS: { [string]: string } = {
	Cherry = "rbxassetid://119982898762335",
	Skull = "rbxassetid://124752643682692",
	Diamond = "rbxassetid://127211345890609",
	Seven = "rbxassetid://109934563325412",
}
local REEL_NAMES = { "Icon1", "Icon2", "Icon3" }
local REEL_DELAY = 0.25
local HIDE_DELAY = 1.5

local currentSpin = 0

return function(_origin: Vector3, params: { [string]: any }?)
	local symbols = params and params.Symbols
	local caster = params and params.Caster
	if type(symbols) ~= "table" or caster == nil or caster ~= Players.LocalPlayer.Character then
		return
	end

	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local icons = playerGui and playerGui:FindFirstChild("DevilFruitIcons")
	local frame = icons and icons:FindFirstChild("Luck")
	if not frame or not frame:IsA("GuiObject") then
		return
	end

	local reels: { ImageLabel } = {}
	for index, reelName in REEL_NAMES do
		local reel = frame:FindFirstChild(reelName)
		local icon = ICONS[symbols[index]]
		if not reel or not reel:IsA("ImageLabel") or not icon then
			return
		end
		reel.Visible = false
		reel.Image = icon
		table.insert(reels, reel)
	end

	currentSpin += 1
	local spin = currentSpin
	frame.Visible = true

	for index, reel in reels do
		if index > 1 then
			task.wait(REEL_DELAY)
		end
		if currentSpin ~= spin then
			return
		end
		reel.Visible = true
	end

	task.wait(HIDE_DELAY)
	if currentSpin == spin then
		for _, reel in reels do
			reel.Visible = false
		end
	end
end
