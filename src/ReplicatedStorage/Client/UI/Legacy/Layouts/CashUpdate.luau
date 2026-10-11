--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.CashUpdate in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "CashUpdate",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.25),
				Size = UDim2.fromScale(0.1, 0.1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				-- legacy behaviour: CashUpdate (LocalScript, 67 lines)
				[Children] = {
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
					}),
					scope:New("TextLabel")({
						Name = "Example",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.fromScale(4, 0.4),
						Text = "+$1000",
						TextColor3 = Color3.fromRGB(0, 255, 0),
						TextScaled = true,
						TextStrokeTransparency = 0.8,
						TextWrapped = true,
						Visible = false,
					}),
				},
			}),
		},
	}) :: any
end
