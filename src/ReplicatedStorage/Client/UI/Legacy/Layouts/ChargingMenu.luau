--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.ChargingMenu in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "ChargingMenu",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				Name = "Table",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.025, 0.5),
				Rotation = 90,
				Size = UDim2.fromScale(0.15, 0.15),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				[Children] = {
					scope:New("UIListLayout")({
						Name = "Layout",
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
						VerticalAlignment = Enum.VerticalAlignment.Bottom,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "ChargeBar",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "http://www.roblox.com/asset/?id=4895148919",
								ImageColor3 = Color3.fromRGB(0, 0, 0),
								Rotation = 90,
								Size = UDim2.fromScale(0.6, 0.1),
								SizeConstraint = Enum.SizeConstraint.RelativeXX,
								-- legacy state not exported: TTL (IntValue)
								[Children] = {
									scope:New("ImageLabel")({
										Name = "Bar",
										AnchorPoint = Vector2.new(1, 0.5),
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										Image = "http://www.roblox.com/asset/?id=4895148919",
										ImageColor3 = Color3.fromRGB(0, 255, 255),
										Position = UDim2.new(1, -1, 0.5, 0),
										Size = UDim2.new(0, -2, 1, -2),
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
