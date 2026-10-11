--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Version in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Version",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("TextLabel")({
				Name = "Version",
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Color3.fromRGB(12, 255, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.new(1, -4, 1, -1),
				Size = UDim2.fromScale(0.4, 0.03),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 999999999,
				-- legacy behaviour: LocalScript (LocalScript, 10 lines)
			}),
			scope:New("TextLabel")({
				Name = "Time",
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Color3.fromRGB(12, 255, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.new(1, -4, 0.971, -1),
				Size = UDim2.fromScale(0.4, 0.03),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 999999999,
				-- legacy behaviour: LocalScript (LocalScript, 10 lines)
			}),
		},
	}) :: any
end
