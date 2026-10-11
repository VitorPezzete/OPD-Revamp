--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.HitCounter in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "HitCounter",
		Enabled = false,
		ResetOnSpawn = true,
		-- legacy behaviour: HitCounterHandler (LocalScript, 45 lines)
		[Children] = {
			scope:New("Frame")({
				Name = "CentralFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				[Children] = {
					scope:New("Frame")({
						Name = "DmgCounterFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.2035, 0.5568),
						Size = UDim2.fromScale(0.1564, 0.1447),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Hits",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(255, 255, 255),
								FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.5, 0.2333),
								Size = UDim2.fromScale(0.7333, 0.4),
								Text = "Hits: Numberx",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0,
								TextWrapped = true,
								[Children] = {
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 50,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Dmg",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(255, 255, 255),
								FontFace = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.5, 0.54),
								Size = UDim2.fromScale(0.8, 0.4),
								Text = "45000",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0,
								TextWrapped = true,
								[Children] = {
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 50,
									}),
								},
							}),
							scope:New("Frame")({
								Name = "TimeBarFrame",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(170, 0, 0),
								Position = UDim2.fromScale(0.5, 0.86),
								Size = UDim2.fromScale(0.8667, 0.06),
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(1, 0),
										BottomRightRadius = UDim.new(1, 0),
										TopLeftRadius = UDim.new(1, 0),
										TopRightRadius = UDim.new(1, 0),
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 2.108,
							}),
						},
					}),
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1.9757,
					}),
				},
			}),
		},
	}) :: any
end
