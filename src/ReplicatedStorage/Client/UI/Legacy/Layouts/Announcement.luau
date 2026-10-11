--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Announcement in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Announcement",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Size = UDim2.fromScale(1, 0.1),
				Visible = false,
				ZIndex = 98,
				[Children] = {
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 0.3,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.fromScale(0.7, 1),
						Text = "Server Will be Restarted",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						ZIndex = 99,
						-- legacy behaviour: Update (LocalScript, 27 lines)
						-- legacy behaviour: Update (LocalScript, 27 lines)
						[Children] = {
							scope:New("TextButton")({
								Name = "Close",
								AnchorPoint = Vector2.new(0.5, 0),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 0.7,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Position = UDim2.fromScale(0.5, 1),
								Size = UDim2.fromScale(0.2, 0.4),
								Text = "Close",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
								ZIndex = 100,
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
