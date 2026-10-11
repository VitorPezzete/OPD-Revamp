--!strict
--[[
	GENERATED v2 from Workspace.Merchants.FlailMerchant.Clickable.ShopFlail in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ShopFlail",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("ObjectValue")({
				Name = "Clicked",
			}),
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(157, 221, 60),
				BackgroundTransparency = 0.2,
				BorderColor3 = Color3.fromRGB(255, 106, 0),
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
						Text = "Timmy",
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
								Text = "Flail",
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
								Text = "50,000",
								TextColor3 = Color3.fromRGB(50, 255, 50),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
						},
					}),
					scope:New("TextLabel")({
						Name = "Dia",
						BackgroundTransparency = 0.6,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.4006, 0.201),
						Size = UDim2.fromScale(0.5007, 0.6263),
						Text = "Hi, I'm Timmy! I like swinging flails at people! I found this one while playing in my backyard. I think it belonged to a squirrel. Wanna buy it?",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
					}),
				},
			}),
		},
	}) :: any
end
