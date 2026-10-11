--!strict
--[[
	GENERATED from ServerStorage.GUIS.GiverGUI in the legacy place: static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "GiverGUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		-- legacy behaviour: MenuScript (LocalScript, 77 lines)
		[Children] = {
			scope:New("ImageLabel")({
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.25),
				Size = UDim2.fromScale(0.4, 0.1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				Image = "rbxassetid://90291183096901",
				ImageColor3 = Color3.fromRGB(131, 181, 255),
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Rect.new(50, 50, 50, 50),
				[Children] = {
					scope:New("Frame")({
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.8, 0.75),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						[Children] = {
							scope:New("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								[Children] = {
									scope:New("TextButton")({
										Name = "Template",
										BorderSizePixel = 1,
										AutoButtonColor = true,
										Size = UDim2.fromScale(1, 0.25),
										BackgroundColor3 = Color3.fromRGB(255, 255, 255),
										BorderColor3 = Color3.fromRGB(0, 0, 0),
										Text = "Player Name",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 14,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
										TextStrokeTransparency = 0.5,
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "1",
								BorderSizePixel = 1,
								Text = "Button",
								AutoButtonColor = true,
								Size = UDim2.fromScale(1, 0.25),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								TextColor3 = Color3.fromRGB(158, 149, 255),
								TextSize = 14,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								TextStrokeTransparency = 0.5,
							}),
						},
					}),
					scope:New("ImageButton")({
						BorderSizePixel = 1,
						AutoButtonColor = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.2, 0.2),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						Image = "rbxassetid://90291183096901",
						ImageColor3 = Color3.fromRGB(131, 181, 255),
						[Children] = {
							scope:New("TextLabel")({
								BorderSizePixel = 1,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.75, 0.75),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								Text = "X",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 17,
								TextScaled = true,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								TextStrokeTransparency = 0.8,
								TextWrapped = true,
							}),
						},
					}),
					scope:New("ImageButton")({
						Name = "ImageButton2",
						BorderSizePixel = 1,
						AutoButtonColor = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromScale(0.2, 0.2),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						Image = "rbxassetid://90291183096901",
						ImageColor3 = Color3.fromRGB(131, 181, 255),
						HoverImage = "rbxassetid://90291183096901",
						[Children] = {
							scope:New("ImageLabel")({
								BorderSizePixel = 1,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								Image = "rbxassetid://89243894789752",
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
