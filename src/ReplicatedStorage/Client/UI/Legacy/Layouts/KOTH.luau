--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.KOTH in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "KOTH",
		Enabled = false,
		ResetOnSpawn = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.1731),
				Size = UDim2.fromScale(0.35, 0.1),
				-- legacy behaviour: Handle (LocalScript, 30 lines)
				[Children] = {
					scope:New("Frame")({
						Name = "BlueTeam",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 0, 255),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.1676, 0.492),
						Size = UDim2.fromScale(0.3352, 0.8209),
						[Children] = {
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 0.9973),
								[Children] = {
									scope:New("UIStroke")({
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.01,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.05, 0),
										BottomRightRadius = UDim.new(0.05, 0),
										TopLeftRadius = UDim.new(0.05, 0),
										TopRightRadius = UDim.new(0.05, 0),
									}),
								},
							}),
							scope:New("TextLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(0, 85, 255),
								BackgroundTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.9, 0.9),
								Text = "Points",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0,
								TextWrapped = true,
								ZIndex = 2,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.05, 0),
										BottomRightRadius = UDim.new(0.05, 0),
										TopLeftRadius = UDim.new(0.05, 0),
										TopRightRadius = UDim.new(0.05, 0),
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.01,
									}),
								},
							}),
						},
					}),
					scope:New("Frame")({
						Name = "RedTeam",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 0, 0),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.8324, 0.492),
						Size = UDim2.fromScale(0.3352, 0.8209),
						[Children] = {
							scope:New("TextLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(255, 0, 0),
								BackgroundTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.9, 0.9),
								Text = "Points",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0,
								TextWrapped = true,
								ZIndex = 2,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.05, 0),
										BottomRightRadius = UDim.new(0.05, 0),
										TopLeftRadius = UDim.new(0.05, 0),
										TopRightRadius = UDim.new(0.05, 0),
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.01,
									}),
								},
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 0.9973),
								[Children] = {
									scope:New("UIStroke")({
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.01,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.05, 0),
										BottomRightRadius = UDim.new(0.05, 0),
										TopLeftRadius = UDim.new(0.05, 0),
										TopRightRadius = UDim.new(0.05, 0),
									}),
								},
							}),
						},
					}),
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5018, 0.5),
						Size = UDim2.fromScale(0.3297, 1),
						[Children] = {
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								[Children] = {
									scope:New("UIStroke")({
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.01,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.05, 0),
										BottomRightRadius = UDim.new(0.05, 0),
										TopLeftRadius = UDim.new(0.05, 0),
										TopRightRadius = UDim.new(0.05, 0),
									}),
								},
							}),
							scope:New("TextLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 0.3,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.9, 0.9),
								Text = "TimeLeft: XX",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0,
								TextWrapped = true,
								ZIndex = 2,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0.05, 0),
										BottomRightRadius = UDim.new(0.05, 0),
										TopLeftRadius = UDim.new(0.05, 0),
										TopRightRadius = UDim.new(0.05, 0),
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
										StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
										Thickness = 0.01,
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
