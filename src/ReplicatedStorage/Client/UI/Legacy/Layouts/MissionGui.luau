--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.MissionGui in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "MissionGui",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0, 0.2613),
				Size = UDim2.fromScale(0.3, 0.15),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = false,
				[Children] = {
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.7,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.1, 0),
						Size = UDim2.fromScale(1, 1),
						Visible = false,
						-- legacy behaviour: MissionGui (LocalScript, 56 lines)
						[Children] = {
							scope:New("TextLabel")({
								Name = "Header",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Size = UDim2.fromScale(1, 0.2),
								Text = "Mission Objective",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.5,
							}),
							scope:New("Frame")({
								Name = "Bar",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.5, 0.85),
								Size = UDim2.fromScale(0.8, 0.08),
								SizeConstraint = Enum.SizeConstraint.RelativeXX,
								[Children] = {
									scope:New("ImageLabel")({
										Name = "Back",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(0, 0, 0),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1),
									}),
									scope:New("ImageLabel")({
										Name = "Front",
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromOffset(1, 1),
										Size = UDim2.new(0.4, -2, 1, -2),
									}),
									scope:New("TextLabel")({
										Name = "Exp",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(121, 164, 255),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1),
										Text = "100000 / 250000",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.5,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Description",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.05, 0.2),
								Size = UDim2.fromScale(0.9, 0.5),
								Text = "[Hard] Earn $250,000 beris.",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.5,
							}),
						},
					}),
				},
			}),
			scope:New("Frame")({
				Name = "LevelUp",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.15),
				Size = UDim2.fromScale(0.2, 0.2),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				-- legacy behaviour: MissionLevelUpEffect (LocalScript, 58 lines)
				[Children] = {
					scope:New("ImageLabel")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "http://www.roblox.com/asset/?id=8553470936",
						ImageColor3 = Color3.fromRGB(255, 255, 0),
						ImageTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
					}),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.5, 0.5),
						Text = "1",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextTransparency = 1,
						TextWrapped = true,
					}),
				},
			}),
		},
	}) :: any
end
