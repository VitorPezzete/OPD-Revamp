--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Top100GUI in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Top100GUI",
		Enabled = false,
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(90, 198, 255),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.7),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				[Children] = {
					scope:New("UICorner")({
						BottomLeftRadius = UDim.new(0, 20),
						BottomRightRadius = UDim.new(0, 20),
						TopLeftRadius = UDim.new(0, 20),
						TopRightRadius = UDim.new(0, 20),
					}),
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(128, 215, 255),
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -20, 1, -20),
						-- legacy behaviour: LocalScript (LocalScript, 97 lines)
						[Children] = {
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(0, 20),
								BottomRightRadius = UDim.new(0, 20),
								TopLeftRadius = UDim.new(0, 20),
								TopRightRadius = UDim.new(0, 20),
							}),
							scope:New("TextLabel")({
								Name = "Header",
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundColor3 = Color3.fromRGB(90, 198, 255),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.5, 0.0125),
								Size = UDim2.fromScale(0.6, 0.08),
								Text = "Top 100 Bounties",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 16,
								TextStrokeTransparency = 0.7,
								TextWrapped = true,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.4, 0),
										BottomRightRadius = UDim.new(0.4, 0),
										TopLeftRadius = UDim.new(0.4, 0),
										TopRightRadius = UDim.new(0.4, 0),
									}),
								},
							}),
							scope:New("Frame")({
								Name = "Board",
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.5, 0.1),
								Size = UDim2.fromScale(0.95, 0.75),
							}),
							scope:New("Frame")({
								Name = "Navigation",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.5, 0.925),
								Size = UDim2.fromScale(0.6, 0.1),
								[Children] = {
									scope:New("ImageButton")({
										Name = "Arrow1",
										AutoButtonColor = true,
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Image = "http://www.roblox.com/asset/?id=6278835808",
										ImageColor3 = Color3.fromRGB(69, 125, 255),
										ImageTransparency = 0.7,
										Position = UDim2.fromScale(0.1, 0),
										Rotation = -90,
										Size = UDim2.fromScale(1, 1),
										SizeConstraint = Enum.SizeConstraint.RelativeYY,
									}),
									scope:New("ImageButton")({
										Name = "Arrow2",
										AnchorPoint = Vector2.new(1, 0),
										AutoButtonColor = true,
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Image = "http://www.roblox.com/asset/?id=6278835808",
										ImageColor3 = Color3.fromRGB(69, 125, 255),
										Position = UDim2.fromScale(0.9, 0),
										Rotation = 90,
										Size = UDim2.fromScale(1, 1),
										SizeConstraint = Enum.SizeConstraint.RelativeYY,
									}),
									scope:New("TextLabel")({
										Name = "PageLabel",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.3, 1),
										Text = "1 - 10",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextSize = 24,
										TextStrokeTransparency = 0.7,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("ImageButton")({
								Name = "Close",
								AnchorPoint = Vector2.new(1, 0),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(255, 142, 142),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.987, 0.013),
								Size = UDim2.fromScale(0.075, 0.075),
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(1, 0),
										BottomRightRadius = UDim.new(1, 0),
										TopLeftRadius = UDim.new(1, 0),
										TopRightRadius = UDim.new(1, 0),
									}),
								},
							}),
							scope:New("Frame")({
								Name = "Template",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(92, 141, 255),
								BackgroundTransparency = 0.7,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.5, 0.05),
								Size = UDim2.fromScale(1, 0.09),
								Visible = false,
								[Children] = {
									scope:New("Frame")({
										Name = "Meter",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Size = UDim2.fromScale(1, 1),
										[Children] = {
											scope:New("Frame")({
												Name = "Bar",
												BackgroundColor3 = Color3.fromRGB(92, 141, 255),
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												Size = UDim2.fromScale(1, 1),
											}),
										},
									}),
									scope:New("TextLabel")({
										Name = "Placement",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(128, 215, 255),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.9, 1),
										Text = "1",
										TextSize = 16,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									scope:New("TextLabel")({
										Name = "User",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(128, 215, 255),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.75, 1),
										Text = "Builderman",
										TextSize = 16,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Left,
									}),
									scope:New("TextLabel")({
										Name = "Bounty",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(128, 215, 255),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.75, 1),
										Text = "123,456,789,000",
										TextSize = 16,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Right,
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
