--!strict
--[[
	GENERATED v2 from Workspace.Merchants.FishMerchant.Clickable.ChefGUI in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ChefGUI",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(221, 83, 36),
				BackgroundTransparency = 0.5,
				BorderColor3 = Color3.fromRGB(255, 72, 55),
				BorderSizePixel = 3,
				Position = UDim2.fromScale(0.15, 0.15),
				Size = UDim2.fromScale(0.7, 0.7),
				[Children] = {
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(36, 221, 193),
						BackgroundTransparency = 0.5,
						BorderColor3 = Color3.fromRGB(53, 211, 255),
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
								Text = "Fish Merchant",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "http://www.roblox.com/asset/?id=5373319844",
								Position = UDim2.fromScale(0.85, 0.55),
								Size = UDim2.fromOffset(238, 238),
								[Children] = {
									scope:New("TextLabel")({
										Name = "LabelName",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										Position = UDim2.fromScale(0, -0.2),
										Size = UDim2.fromScale(1, 0.2),
										Text = "Chef",
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
				-- legacy remote: Retum (RemoteEvent)
			}),
			scope:New("IntValue")({
				Name = "ChatProgress",
			}),
			scope:New("Sound")({
				Name = "MenuPop",
				SoundId = "rbxassetid://5614012557",
			}),
		},
	}) :: any
end
