--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Fishing in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Fishing",
		ResetOnSpawn = true,
		-- legacy state not exported: Rod (StringValue)
		-- legacy state not exported: Active (BoolValue)
		[Children] = {
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(28, 39, 255),
				BackgroundTransparency = 0.2,
				Size = UDim2.fromScale(1, 1),
				Visible = false,
				-- legacy behaviour: Fishing (LocalScript, 396 lines)
				[Children] = {
					scope:New("TextButton")({
						Name = "Template",
						AutoButtonColor = true,
						BackgroundColor3 = Color3.fromRGB(150, 150, 150),
						Position = UDim2.fromScale(0.4621, 0.4238),
						Selectable = false,
						Size = UDim2.fromScale(0.075, 0.15),
						Visible = false,
						[Children] = {
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(5, 0),
								BottomRightRadius = UDim.new(5, 0),
								TopLeftRadius = UDim.new(5, 0),
								TopRightRadius = UDim.new(5, 0),
							}),
							scope:New("Frame")({
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(-1, -1),
								Size = UDim2.fromScale(3, 3),
								[Children] = {
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Color = Color3.fromRGB(100, 100, 100),
										Thickness = 6,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(5, 0),
										BottomRightRadius = UDim.new(5, 0),
										TopLeftRadius = UDim.new(5, 0),
										TopRightRadius = UDim.new(5, 0),
									}),
									scope:New("UIAspectRatioConstraint")({
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "Difficulty",
						BackgroundColor3 = Color3.fromRGB(25, 40, 255),
						BackgroundTransparency = 0.5,
						Position = UDim2.fromScale(0.3995, 0),
						Size = UDim2.fromScale(0.2, 0.1),
						Text = "Label",
						TextScaled = true,
						TextWrapped = true,
					}),
					scope:New("TextLabel")({
						Name = "Count",
						BackgroundColor3 = Color3.fromRGB(34, 38, 255),
						Position = UDim2.fromScale(0.4491, 0.0996),
						Size = UDim2.fromScale(0.1, 0.05),
						Text = "Label",
						TextScaled = true,
						TextWrapped = true,
					}),
					scope:New("Frame")({
						Name = "Controller",
						BackgroundColor3 = Color3.fromRGB(73, 76, 255),
						Position = UDim2.fromScale(0, 0.4397),
						Size = UDim2.fromScale(1, 0.1),
						Visible = false,
						[Children] = {
							scope:New("Frame")({
								BackgroundTransparency = 0.2,
								Position = UDim2.fromScale(0.3, 0),
								Size = UDim2.fromScale(0.4, 1.013),
							}),
							scope:New("ImageButton")({
								Name = "TemplateController",
								AutoButtonColor = true,
								Image = "rbxassetid://135685790731603",
								ImageColor3 = Color3.fromRGB(39, 143, 255),
								Position = UDim2.fromScale(0.299, 0),
								Rotation = 180,
								Selectable = false,
								Size = UDim2.fromScale(0.045, 1.013),
								Visible = false,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Error",
						AutoButtonColor = true,
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Text = "Button",
						TextTransparency = 1,
					}),
					scope:New("Frame")({
						Name = "DragTemplate",
						Position = UDim2.fromScale(0.2934, 0.1525),
						Size = UDim2.fromOffset(100, 340),
						Visible = false,
						[Children] = {
							scope:New("TextButton")({
								AutoButtonColor = true,
								Position = UDim2.fromScale(0.02, 0),
								Size = UDim2.fromScale(0.95, 0.2853),
								ZIndex = 2,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 50),
										BottomRightRadius = UDim.new(0, 50),
										TopLeftRadius = UDim.new(0, 50),
										TopRightRadius = UDim.new(0, 50),
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										Thickness = 4,
									}),
									scope:New("UIAspectRatioConstraint")({
									}),
									scope:New("UIDragDetector")({
									}),
								},
							}),
							scope:New("Frame")({
								Name = "Target",
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 1,
								LayoutOrder = 1,
								Position = UDim2.fromScale(0, 0.7059),
								Size = UDim2.fromOffset(100, 100),
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 45),
										BottomRightRadius = UDim.new(0, 45),
										TopLeftRadius = UDim.new(0, 45),
										TopRightRadius = UDim.new(0, 45),
									}),
									scope:New("UIAspectRatioConstraint")({
									}),
								},
							}),
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(0, 45),
								BottomRightRadius = UDim.new(0, 45),
								TopLeftRadius = UDim.new(0, 45),
								TopRightRadius = UDim.new(0, 45),
							}),
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(0, 45),
								BottomRightRadius = UDim.new(0, 45),
								TopLeftRadius = UDim.new(0, 45),
								TopRightRadius = UDim.new(0, 45),
							}),
							scope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Thickness = 4,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Bait",
						AutoButtonColor = true,
						BackgroundTransparency = 0.9,
						Position = UDim2.fromScale(0.318, 0.3664),
						Size = UDim2.fromScale(0.01, 0.02),
						Visible = false,
						[Children] = {
							scope:New("UIAspectRatioConstraint")({
							}),
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(5, 0),
								BottomRightRadius = UDim.new(5, 0),
								TopLeftRadius = UDim.new(5, 0),
								TopRightRadius = UDim.new(5, 0),
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
