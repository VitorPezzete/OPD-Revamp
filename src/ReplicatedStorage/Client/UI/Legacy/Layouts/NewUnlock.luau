--!strict
--[[
	GENERATED v2 from ReplicatedStorage.Assets.Models.World.Stored.FromServerScripts.etc.Unlock.NewUnlock in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "NewUnlock",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("CanvasGroup")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.25),
				Size = UDim2.fromScale(0.7, 0.1),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				[Children] = {
					scope:New("Sound")({
						Name = "Success",
						SoundId = "rbxassetid://3997124966",
					}),
					scope:New("ImageLabel")({
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://13656415409",
						Size = UDim2.fromScale(1, 1),
					}),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 0.4),
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextWrapped = true,
					}),
				},
			}),
		},
	}) :: any
end
