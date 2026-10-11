--!strict
--[[
	GENERATED v2 from Workspace.Merchants.SniperMerchant.Clickable.ShopSniper in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ShopSniper",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("ObjectValue")({
				Name = "Clicked",
				-- legacy remote: Retum (RemoteEvent)
			}),
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(84, 162, 221),
				BackgroundTransparency = 0.2,
				BorderColor3 = Color3.fromRGB(163, 160, 255),
				BorderSizePixel = 3,
				Position = UDim2.fromScale(0.25, 0.25),
				Size = UDim2.fromScale(0.5, 0.5),
				[Children] = {
					scope:New("TextLabel")({
						Name = "Shop",
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Size = UDim2.fromScale(1, 0.15),
						Text = "Sniper Shop",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
					}),
					scope:New("Frame")({
						Name = "A",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.2,
						BorderColor3 = Color3.fromRGB(0, 132, 255),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.07, 0.25),
						Size = UDim2.fromScale(0.2, 0.4),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Label",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.fromScale(1, 0.3),
								Text = "Slingshot",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageButton")({
								AutoButtonColor = true,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://133293265",
								Size = UDim2.fromScale(1, 1),
							}),
							scope:New("TextLabel")({
								Name = "Cash",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1.3),
								Size = UDim2.fromScale(1, 0.3),
								Text = "1,000",
								TextColor3 = Color3.fromRGB(50, 255, 50),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "B",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.2,
						BorderColor3 = Color3.fromRGB(0, 132, 255),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.29, 0.25),
						Size = UDim2.fromScale(0.2, 0.4),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Label",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.fromScale(1, 0.3),
								Text = "Stars",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageButton")({
								AutoButtonColor = true,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://133293265",
								Size = UDim2.fromScale(1, 1),
							}),
							scope:New("TextLabel")({
								Name = "Cash",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1.3),
								Size = UDim2.fromScale(1, 0.3),
								Text = "5,000",
								TextColor3 = Color3.fromRGB(50, 255, 50),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "C",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.2,
						BorderColor3 = Color3.fromRGB(0, 132, 255),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.51, 0.25),
						Size = UDim2.fromScale(0.2, 0.4),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Label",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.fromScale(1, 0.3),
								Text = "Crossbow",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageButton")({
								AutoButtonColor = true,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://133293265",
								Size = UDim2.fromScale(1, 1),
							}),
							scope:New("TextLabel")({
								Name = "Cash",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1.3),
								Size = UDim2.fromScale(1, 0.3),
								Text = "7,500",
								TextColor3 = Color3.fromRGB(50, 255, 50),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "D",
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.2,
						BorderColor3 = Color3.fromRGB(0, 132, 255),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.73, 0.25),
						Size = UDim2.fromScale(0.2, 0.4),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Label",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.fromScale(1, 0.3),
								Text = "Flintlock",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageButton")({
								AutoButtonColor = true,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://133293265",
								Size = UDim2.fromScale(1, 1),
							}),
							scope:New("TextLabel")({
								Name = "Cash",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0, 1.3),
								Size = UDim2.fromScale(1, 0.3),
								Text = "10,000",
								TextColor3 = Color3.fromRGB(50, 255, 50),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
