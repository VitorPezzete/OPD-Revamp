--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.MouseTipPerkPoints in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "MouseTipPerkPoints",
		DisplayOrder = 51,
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Color3.fromRGB(156, 171, 255),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.7382, 0.4223),
				Size = UDim2.fromScale(0.5, 0.1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = false,
				-- legacy behaviour: MouseTipPerks (LocalScript, 55 lines)
				[Children] = {
					scope:New("ImageLabel")({
						Name = "Triangle",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Image = "http://www.roblox.com/asset/?id=7118241629",
						ImageColor3 = Color3.fromRGB(156, 171, 255),
						Position = UDim2.new(1.045, 1, 0.5, 0),
						Rotation = -90,
						Size = UDim2.fromScale(1, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
					}),
					scope:New("TextLabel")({
						Name = "Description",
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.fromScale(0.4, 0.8),
						Text = "No Points Invested",
						TextColor3 = Color3.fromRGB(255, 255, 128),
						TextSize = 24,
						TextStrokeTransparency = 0.5,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextWrapped = true,
					}),
					scope:New("ImageLabel")({
						Name = "PerkIcon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=8530145081",
						Position = UDim2.fromScale(0.1, 0.6),
						Size = UDim2.fromScale(0.5, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "PerkIcon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=8530145081",
								ImageColor3 = Color3.fromRGB(255, 255, 0),
								ImageTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
							}),
						},
					}),
					scope:New("ImageLabel")({
						Name = "PerkIcon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=8530145081",
						Position = UDim2.fromScale(0.16, 0.6),
						Size = UDim2.fromScale(0.5, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "PerkIcon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=8530145081",
								ImageColor3 = Color3.fromRGB(0, 255, 0),
								ImageTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
							}),
						},
					}),
					scope:New("ImageLabel")({
						Name = "PerkIcon",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=8530145081",
						Position = UDim2.fromScale(0.13, 0.4),
						Size = UDim2.fromScale(0.5, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "PerkIcon",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=8530145081",
								ImageColor3 = Color3.fromRGB(255, 0, 0),
								ImageTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
							}),
						},
					}),
					scope:New("ImageLabel")({
						Name = "Arrow",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=6278835808",
						Position = UDim2.fromScale(0.3, 0.5),
						Rotation = 90,
						Size = UDim2.fromScale(0.5, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
					}),
					scope:New("ImageLabel")({
						Name = "Points",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://2204238988",
						ImageColor3 = Color3.fromRGB(102, 130, 255),
						Position = UDim2.fromScale(0.45, 0.5),
						Size = UDim2.fromScale(0.8, 0.8),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
					}),
				},
			}),
		},
	}) :: any
end
