--!strict
--[[
	GENERATED v2 from Workspace.Merchants.QuestFishMerchant.Clickable.QuestFish in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "QuestFish",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("ObjectValue")({
				Name = "Clicked",
			}),
			scope:New("IntValue")({
				Name = "ChatProgress",
			}),
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(22, 162, 221),
				BackgroundTransparency = 0.5,
				BorderColor3 = Color3.fromRGB(28, 69, 255),
				BorderSizePixel = 3,
				Position = UDim2.fromScale(0.15, 0.15),
				Size = UDim2.fromScale(0.7, 0.7),
				[Children] = {
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(21, 221, 128),
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
								Size = UDim2.fromScale(1, 0.15),
								Text = "Fishman Fisherman",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://2724931472",
								Position = UDim2.fromScale(0.85, 0.55),
								Size = UDim2.fromOffset(238, 238),
								[Children] = {
									scope:New("TextLabel")({
										Name = "LabelName",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0, -0.2),
										Size = UDim2.fromScale(1, 0.2),
										Text = "Merlin",
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
								Position = UDim2.fromScale(0.3, 0.2),
								Size = UDim2.fromScale(0.4, 0.4),
								Text = "Fishing isn't a hobby, it's a way of life! You look like you might enjoy it, but I'm not sure if you're ready to be a fishing master. How about you help me out and I'll give you one of my old rods?",
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
								Position = UDim2.fromScale(0.5, 0.8),
								Size = UDim2.fromScale(0.3, 0.1),
								[Children] = {
									scope:New("TextButton")({
										Name = "Accept",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0.5, 0.5),
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
							scope:New("Frame")({
								Name = "GoldenCompassFrame",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(48, 48, 48),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.85, 0.9),
								Size = UDim2.fromScale(0.25, 0.035),
								[Children] = {
									scope:New("Frame")({
										BackgroundColor3 = Color3.fromRGB(14, 38, 255),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Size = UDim2.fromScale(0.18, 1),
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
										Size = UDim2.fromScale(1, 1.5),
										Text = "Merlin's Trust",
										TextColor3 = Color3.fromRGB(14, 38, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.6,
										TextWrapped = true,
									}),
									scope:New("TextLabel")({
										Name = "Progress",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0, 1),
										Size = UDim2.fromScale(1, 1.25),
										Text = "9 / 50",
										TextColor3 = Color3.fromRGB(14, 38, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.6,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("ImageLabel")({
								Name = "Pic",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "http://www.roblox.com/asset/?id=7242949418",
								Position = UDim2.fromScale(0.15, 0.5),
								Size = UDim2.fromScale(0.4, 0.4),
								SizeConstraint = Enum.SizeConstraint.RelativeYY,
								Visible = false,
								[Children] = {
									scope:New("TextLabel")({
										Name = "LabelName",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0, -0.2),
										Size = UDim2.fromScale(1, 0.2),
										Text = "Super Rod",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.5,
										TextWrapped = true,
									}),
									scope:New("TextButton")({
										Name = "Accept",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0.5, 1.2),
										Size = UDim2.fromScale(1, 0.2),
										Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
										Text = "$1,000,000",
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
		},
	}) :: any
end
