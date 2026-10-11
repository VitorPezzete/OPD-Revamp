--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.MouseTipPerks in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "MouseTipPerks",
		DisplayOrder = 51,
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.6159, 0.5484),
				Size = UDim2.fromScale(0.5, 0.25),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = false,
				-- legacy behaviour: MouseTipPerks (LocalScript, 29 lines)
				-- legacy state not exported: HoveringButtons (IntValue)
				[Children] = {
					scope:New("ImageLabel")({
						Name = "PerkIcon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=8530145081",
						Position = UDim2.fromScale(0.2, 0.35),
						Size = UDim2.fromScale(0.5, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						[Children] = {
							scope:New("Frame")({
								Name = "ProgressFrame",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								ClipsDescendants = true,
								Position = UDim2.fromScale(0, 0.2),
								Size = UDim2.fromScale(1, 1),
								[Children] = {
									scope:New("ImageLabel")({
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										ClipsDescendants = true,
										Image = "http://www.roblox.com/asset/?id=8530145081",
										ImageColor3 = Color3.fromRGB(115, 159, 255),
										ImageTransparency = 0.5,
										Position = UDim2.fromScale(0, -0.2),
										Size = UDim2.fromScale(1, 1),
									}),
								},
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=8530041421",
								ImageColor3 = Color3.fromRGB(115, 159, 255),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
							}),
						},
					}),
					scope:New("ImageLabel")({
						Name = "Triangle",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=7118241629",
						ImageColor3 = Color3.fromRGB(40, 40, 40),
						Position = UDim2.new(1.125, 1, 0.5, 0),
						Rotation = -90,
						Size = UDim2.new(1, 2, 0.5, 2),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
					}),
					scope:New("TextLabel")({
						Name = "Progress",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.2, 0.75),
						Size = UDim2.fromScale(0.4, 0.2),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						Text = "16 / 20",
						TextWrapped = true,
						[Children] = {
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(0.2, 0),
								BottomRightRadius = UDim.new(0.2, 0),
								TopLeftRadius = UDim.new(0.2, 0),
								TopRightRadius = UDim.new(0.2, 0),
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "Description",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.65, 0.5),
						Size = UDim2.fromScale(0.55, 0.8),
						Text = "Reduces the amount of damage taken from weapons by 2% per level.",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 16,
						TextStrokeTransparency = 0.5,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextWrapped = true,
					}),
				},
			}),
		},
	}) :: any
end
