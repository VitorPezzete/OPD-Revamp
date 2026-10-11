--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Blindness in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Blindness",
		DisplayOrder = 101,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("CanvasGroup")({
				Name = "Frame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(2, 2),
				Visible = false,
				-- legacy behaviour: LocalScript (LocalScript, 16 lines)
				[Children] = {
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.5, 0.5),
						SizeConstraint = Enum.SizeConstraint.RelativeYY,
						ZIndex = 0,
						-- legacy behaviour: LocalScript (LocalScript, 110 lines)
						[Children] = {
							scope:New("Frame")({
								Name = "Bar1",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(53, 53, 53),
								BorderColor3 = Color3.fromRGB(147, 147, 147),
								BorderSizePixel = 4,
								Position = UDim2.fromScale(0.5, 0.48),
								Size = UDim2.fromScale(0.6, 0.01),
								Visible = false,
								[Children] = {
									scope:New("Frame")({
										Name = "LoadingBar",
										AnchorPoint = Vector2.new(0, 0.5),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0, 0.5),
										Size = UDim2.fromScale(0, 1),
									}),
								},
							}),
							scope:New("Frame")({
								Name = "Bar2",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(53, 53, 53),
								BorderColor3 = Color3.fromRGB(147, 147, 147),
								BorderSizePixel = 4,
								Position = UDim2.fromScale(0.5, 0.52),
								Size = UDim2.fromScale(0.6, 0.01),
								Visible = false,
								[Children] = {
									scope:New("Frame")({
										Name = "LoadingBar",
										AnchorPoint = Vector2.new(0, 0.5),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										Position = UDim2.fromScale(0, 0.5),
										Size = UDim2.fromScale(0, 1),
									}),
								},
							}),
							scope:New("TextLabel")({
								AnchorPoint = Vector2.new(0.5, 0),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.5, 0.4),
								Size = UDim2.fromScale(0.5, 0.04),
								Text = "Waiting for servers to catch up.",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 16,
								TextStrokeTransparency = 0.5,
								Visible = false,
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
