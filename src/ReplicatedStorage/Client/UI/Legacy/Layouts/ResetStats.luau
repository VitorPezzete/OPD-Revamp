--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.ResetStats in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ResetStats",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.35, 0.15),
				Size = UDim2.fromScale(0.3, 0.6),
				Visible = false,
				[Children] = {
					scope:New("TextButton")({
						Name = "A",
						AutoButtonColor = true,
						BackgroundColor3 = Color3.fromRGB(61, 61, 61),
						BorderColor3 = Color3.fromRGB(255, 0, 0),
						BorderSizePixel = 2,
						Position = UDim2.fromScale(0.05, 0.75),
						Size = UDim2.fromScale(0.4, 0.2),
						Text = "RESET",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 10 lines)
					}),
					scope:New("TextButton")({
						Name = "B",
						AutoButtonColor = true,
						BackgroundColor3 = Color3.fromRGB(61, 61, 61),
						BorderColor3 = Color3.fromRGB(255, 0, 0),
						BorderSizePixel = 2,
						Position = UDim2.fromScale(0.55, 0.75),
						Size = UDim2.fromScale(0.4, 0.2),
						Text = "CLOSE",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 6 lines)
					}),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Size = UDim2.fromScale(1, 0.7),
						Text = "This action will set all stats back to default. There is no way to revert to your old data.",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextWrapped = true,
					}),
				},
			}),
		},
	}) :: any
end
