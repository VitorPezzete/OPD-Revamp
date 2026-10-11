--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.MenuNew > Frame > Frame): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): Frame
	return scope:New("Frame")({
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Position = UDim2.fromScale(1, -0.25),
		Size = UDim2.fromOffset(113, 113),
		ZIndex = 10,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(87, 137, 255),
				BackgroundTransparency = 1,
				BorderSizePixel = 5,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 45,
				Size = UDim2.fromScale(0.65, 0.65),
				ZIndex = 5,
			}),
			scope:New("TextLabel")({
				Name = "Label",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextTransparency = 1,
				TextWrapped = true,
				ZIndex = 5,
			}),
		},
	}) :: any
end
