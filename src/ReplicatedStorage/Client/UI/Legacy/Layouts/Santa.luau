--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Santa in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Santa",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		-- legacy behaviour: LocalScript (LocalScript, 116 lines)
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(221, 199, 216),
				BackgroundTransparency = 0.5,
				BorderColor3 = Color3.fromRGB(56, 6, 77),
				BorderSizePixel = 3,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.2, 0.6),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = false,
				[Children] = {
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(221, 37, 62),
						BackgroundTransparency = 0.5,
						BorderColor3 = Color3.fromRGB(51, 6, 71),
						BorderSizePixel = 3,
						Position = UDim2.fromScale(0.025, 0.025),
						Size = UDim2.fromScale(0.95, 0.95),
						[Children] = {
							scope:New("TextLabel")({
								Name = "shop",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Size = UDim2.fromScale(1, 0.15),
								Text = "Joy To The World!",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageLabel")({
								Name = "NPC",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://93582926537892",
								Position = UDim2.fromScale(0.85, 0.4973),
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
								Text = "Ho Ho Ho! Merry Christmas! Mind helping me make this christimas special? I Lost all my candy, do you got some there?",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("TextLabel")({
								Name = "LowerLabelWarning",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.5, 0.85),
								Size = UDim2.fromScale(0.25, 0.08),
								Text = "You must be the private server owner to claim VIP Compass Tokens.",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
								Visible = false,
							}),
							scope:New("TextButton")({
								Name = "Complete",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(158, 158, 158),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.5081, 0.8704),
								Size = UDim2.fromScale(0.2296, 0.11),
								Text = "Complete Task",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextSize = 5,
								TextStrokeTransparency = 0.7,
								TextWrapped = true,
								[Children] = {
									scope:New("UICorner")({
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Task",
								BackgroundColor3 = Color3.fromRGB(249, 76, 255),
								BackgroundTransparency = 0.7,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.3575, 0.3637),
								Size = UDim2.fromScale(0.3009, 0.2686),
								Text = "Bring a Candy Fruit",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("Frame")({
								Name = "Quantity",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(48, 48, 48),
								BorderSizePixel = 1,
								Position = UDim2.fromScale(0.85, 0.9),
								Size = UDim2.fromScale(0.25, 0.035),
								[Children] = {
									scope:New("Frame")({
										BackgroundColor3 = Color3.fromRGB(124, 37, 255),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Size = UDim2.fromScale(0.18, 1),
										-- legacy behaviour: Gifts (LocalScript, 20 lines)
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0, 1),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
										Size = UDim2.fromScale(1, 1.5),
										Text = "Players gifted",
										TextColor3 = Color3.fromRGB(124, 37, 255),
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
										Text = "0 / 10",
										TextColor3 = Color3.fromRGB(124, 37, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.6,
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
