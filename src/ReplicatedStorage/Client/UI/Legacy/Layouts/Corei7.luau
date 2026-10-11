--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Core_i7 in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Core_i7",
		Enabled = false,
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		-- legacy behaviour: Core_i7 (LocalScript, 158 lines)
		[Children] = {
			scope:New("Frame")({
				Name = "PlayerListContainer",
				BackgroundColor3 = Color3.fromRGB(163, 162, 165),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.new(1, -247, 0, 2),
				Size = UDim2.new(0, 247, 0.5, 0),
				-- legacy state not exported: Ignore (Folder)
				[Children] = {
					scope:New("UIGridLayout")({
						CellPadding = UDim2.fromOffset(0, 2),
						CellSize = UDim2.new(1, 0, 0, 24),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				},
			}),
			scope:New("ImageButton")({
				Name = "ShowButton",
				AnchorPoint = Vector2.new(1, 0),
				AutoButtonColor = true,
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Image = "http://www.roblox.com/asset/?id=5648080970",
				ImageColor3 = Color3.fromRGB(0, 0, 0),
				ImageTransparency = 0.5,
				Position = UDim2.new(1, -3, 0, 3),
				Size = UDim2.fromOffset(20, 20),
				Visible = false,
			}),
		},
	}) :: any
end
