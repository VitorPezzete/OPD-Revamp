--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.ExpertiseBonusAlert in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ExpertiseBonusAlert",
		ResetOnSpawn = true,
		-- legacy behaviour: ExpertiseBonusAlert (LocalScript, 33 lines)
		[Children] = {
			scope:New("Frame")({
				Name = "Template",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.4, 0.03),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Visible = false,
				[Children] = {
					scope:New("TextLabel")({
						Name = "Label",
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Size = UDim2.fromScale(1, 1),
						Text = "Sam's Quest Progress Bonus!",
						TextColor3 = Color3.fromRGB(255, 191, 0),
						TextScaled = true,
						TextWrapped = true,
					}),
				},
			}),
		},
	}) :: any
end
