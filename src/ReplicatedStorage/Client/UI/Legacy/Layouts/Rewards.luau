--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Rewards in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Rewards",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0, 0.45),
				Size = UDim2.fromOffset(244, 244),
				Visible = false,
				[Children] = {
					scope:New("ImageLabel")({
						Name = "Box1",
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://2923887569",
						Size = UDim2.fromScale(0.4, 0.4),
						Visible = false,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "Lid",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "rbxassetid://2923888043",
								Size = UDim2.fromScale(1, 1),
							}),
							scope:New("ImageButton")({
								AutoButtonColor = true,
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Size = UDim2.fromScale(1, 1),
							}),
						},
					}),
					scope:New("ImageLabel")({
						Name = "Box2",
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://2923887431",
						Position = UDim2.fromScale(0, 0.6),
						Size = UDim2.fromScale(0.4, 0.4),
						Visible = false,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "Lid",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "rbxassetid://2923887976",
								Size = UDim2.fromScale(1, 1),
							}),
							scope:New("ImageButton")({
								AutoButtonColor = true,
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Size = UDim2.fromScale(1, 1),
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
