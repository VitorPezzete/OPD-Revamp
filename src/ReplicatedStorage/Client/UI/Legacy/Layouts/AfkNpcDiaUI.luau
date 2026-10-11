--!strict
--[[
	GENERATED v2 from Workspace.Merchants.AFK_NPC.Clickable.AfkNpcDiaUI in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "AfkNpcDiaUI",
		ResetOnSpawn = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		[Children] = {
			scope:New("Frame")({
				Name = "CentralFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				[Children] = {
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 170, 0),
						BackgroundTransparency = 0.5,
						BorderColor3 = Color3.fromRGB(0, 255, 0),
						BorderSizePixel = 3,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1.2, 0.6),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						[Children] = {
							scope:New("TextButton")({
								Name = "Sell",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(158, 158, 158),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.4993, 0.9132),
								Size = UDim2.fromScale(0.2296, 0.11),
								Text = "Claim Rewards",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 5,
								TextStrokeTransparency = 0.7,
								TextWrapped = true,
								[Children] = {
									scope:New("UIStroke")({
									}),
									scope:New("UICorner")({
									}),
								},
							}),
							scope:New("ImageLabel")({
								Name = "NPC",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://0",
								Position = UDim2.fromScale(0.8309, 0.5),
								Size = UDim2.fromScale(0.5, 0.5),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
							}),
							scope:New("TextLabel")({
								Name = "Dia",
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 0.7,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.05, 0.2),
								Size = UDim2.fromScale(0.25, 0.7),
								Text = "Dialogue Template Bla Bla Bla",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("TextLabel")({
								Name = "Shop",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Size = UDim2.fromScale(1, 0.15),
								Text = "Npc Name",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("Frame")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5191),
								Size = UDim2.fromScale(0.3, 0.6381),
								[Children] = {
									scope:New("TextLabel")({
										Name = "BeriReward",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.25,
										Position = UDim2.fromScale(0.5, 0.1063),
										Size = UDim2.fromScale(1, 0.2127),
										Text = "Beri: xx",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0,
										TextWrapped = true,
										ZIndex = 2,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
										},
									}),
									scope:New("TextLabel")({
										Name = "GemsReward",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.25,
										Position = UDim2.fromScale(0.5, 0.3291),
										Size = UDim2.fromScale(1, 0.208),
										Text = "Gems: xx",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0,
										TextWrapped = true,
										ZIndex = 2,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
										},
									}),
									scope:New("TextLabel")({
										Name = "CompassReward",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.25,
										Position = UDim2.fromScale(0.5, 0.5477),
										Size = UDim2.fromScale(1, 0.2043),
										Text = "Compass: xx",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0,
										TextWrapped = true,
										ZIndex = 2,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
										},
									}),
									scope:New("TextLabel")({
										Name = "SilverReward",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.25,
										Position = UDim2.fromScale(0.5, 0.763),
										Size = UDim2.fromScale(1, 0.2014),
										Text = "Silver Compass: xx",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0,
										TextWrapped = true,
										ZIndex = 2,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
										},
									}),
									scope:New("TextLabel")({
										Name = "GoldenReward",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.25,
										Position = UDim2.fromScale(0.5, 0.9756),
										Size = UDim2.fromScale(1, 0.199),
										Text = "Golden Compass: xx",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0,
										TextWrapped = true,
										ZIndex = 2,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
										},
									}),
									scope:New("UIListLayout")({
										HorizontalAlignment = Enum.HorizontalAlignment.Center,
										HorizontalFlex = Enum.UIFlexAlignment.Fill,
										Padding = UDim.new(0, 2),
										SortOrder = Enum.SortOrder.LayoutOrder,
										VerticalAlignment = Enum.VerticalAlignment.Bottom,
										VerticalFlex = Enum.UIFlexAlignment.Fill,
									}),
								},
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
