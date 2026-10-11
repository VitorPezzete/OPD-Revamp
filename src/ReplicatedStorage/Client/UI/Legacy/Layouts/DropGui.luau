--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.DropGui in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "DropGui",
		Enabled = false,
		ResetOnSpawn = true,
		-- legacy behaviour: DropClient (LocalScript, 111 lines)
		[Children] = {
			scope:New("ImageLabel")({
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Image = "rbxassetid://90291183096901",
				ImageColor3 = Color3.fromRGB(131, 181, 255),
				Position = UDim2.fromScale(0.5, 0.25),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(0.4, 0.1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				SliceCenter = Rect.new(50, 50, 50, 50),
				[Children] = {
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.8, 0.75),
						SizeConstraint = Enum.SizeConstraint.RelativeXX,
						[Children] = {
							scope:New("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
								[Children] = {
									scope:New("TextButton")({
										Name = "Template",
										AutoButtonColor = true,
										BorderSizePixel = 1,
										Size = UDim2.fromScale(1, 0.25),
										SizeConstraint = Enum.SizeConstraint.RelativeXX,
										Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
										Text = "Player Name",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextStrokeTransparency = 0.5,
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "1",
								AutoButtonColor = true,
								BorderSizePixel = 1,
								Size = UDim2.fromScale(1, 0.25),
								SizeConstraint = Enum.SizeConstraint.RelativeXX,
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Button",
								TextColor3 = Color3.fromRGB(158, 149, 255),
								TextStrokeTransparency = 0.5,
							}),
						},
					}),
					scope:New("ImageButton")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BackgroundTransparency = 1,
						BorderSizePixel = 1,
						Image = "rbxassetid://90291183096901",
						ImageColor3 = Color3.fromRGB(131, 181, 255),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(0.2, 0.2),
						SizeConstraint = Enum.SizeConstraint.RelativeXX,
						[Children] = {
							scope:New("TextLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.75, 0.75),
								Text = "X",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 17,
								TextStrokeTransparency = 0.8,
								TextWrapped = true,
							}),
						},
					}),
					scope:New("ImageButton")({
						Name = "ImageButton2",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BackgroundTransparency = 1,
						BorderSizePixel = 1,
						HoverImage = "rbxassetid://90291183096901",
						Image = "rbxassetid://90291183096901",
						ImageColor3 = Color3.fromRGB(131, 181, 255),
						Size = UDim2.fromScale(0.2, 0.2),
						SizeConstraint = Enum.SizeConstraint.RelativeXX,
						[Children] = {
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderSizePixel = 1,
								Image = "rbxassetid://89243894789752",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.5, 0.5),
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
