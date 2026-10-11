--!strict
--[[
	GENERATED v2 from ReplicatedStorage.Assets.Models.Weapons.Sword.Yamato.YamatoGUI in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "YamatoGUI",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("ImageLabel")({
				Name = "MainFrame",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(248, 248, 248),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Image = "rbxassetid://1327087642",
				ImageTransparency = 0.48,
				Position = UDim2.fromScale(0.4995, 0.0727),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.2814, 0.1694),
				SliceCenter = Rect.new(20, 20, 190, 190),
				[Children] = {
					scope:New("TextBox")({
						BackgroundColor3 = Color3.fromRGB(44, 44, 44),
						BackgroundTransparency = 1,
						ClearTextOnFocus = true,
						PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
						Position = UDim2.fromScale(0.1051, 0.2651),
						Size = UDim2.fromOffset(192, 37),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextWrapped = true,
						ZIndex = 5,
					}),
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 2.8375,
					}),
				},
			}),
		},
	}) :: any
end
