--!strict
--[[
	GENERATED v2 from Workspace.Merchants.QuestHakiMerchant.Clickable.QuestHaki in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "QuestHaki",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(113, 114, 221),
				BackgroundTransparency = 0.5,
				BorderColor3 = Color3.fromRGB(28, 69, 255),
				BorderSizePixel = 3,
				Position = UDim2.fromScale(0.15, 0.15),
				Size = UDim2.fromScale(0.7, 0.7),
				[Children] = {
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(46, 5, 80),
						BackgroundTransparency = 0.5,
						BorderColor3 = Color3.fromRGB(28, 69, 255),
						BorderSizePixel = 3,
						Position = UDim2.fromScale(0.025, 0.025),
						Size = UDim2.fromScale(0.95, 0.95),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Shop",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Size = UDim2.fromScale(1, 0.15),
								Text = "Haki Master",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://2776110574",
								Position = UDim2.fromScale(0.85, 0.55),
								Size = UDim2.fromOffset(227, 227),
								[Children] = {
									scope:New("TextLabel")({
										Name = "LabelName",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0, -0.2),
										Size = UDim2.fromScale(1, 0.2),
										Text = "Silvers Rayleigh",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.5,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Dia",
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 0.7,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.1, 0.2),
								Size = UDim2.fromScale(0.6, 0.6),
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageButton")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.55, 0.9),
								Size = UDim2.fromScale(0.3, 0.1),
								[Children] = {
									scope:New("TextButton")({
										Name = "Accept",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0, 0.5),
										Size = UDim2.fromScale(1, 1.4),
										Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
										Text = "Next",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.7,
										TextWrapped = true,
									}),
								},
							}),
						},
					}),
				},
			}),
			scope:New("ObjectValue")({
				Name = "Clicked",
			}),
			scope:New("IntValue")({
				Name = "ChatProgress",
			}),
		},
	}) :: any
end
