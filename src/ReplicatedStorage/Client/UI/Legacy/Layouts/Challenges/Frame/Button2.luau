--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Challenges > Frame > Button2): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ImageButton
	return scope:New("ImageButton")({
		Name = "Button2",
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(113, 79, 68),
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Position = UDim2.fromScale(0.51, 0.12),
		Size = UDim2.fromScale(0.2, 0.09),
		[Children] = {
			scope:New("UICorner")({
				BottomLeftRadius = UDim.new(0.2, 0),
				BottomRightRadius = UDim.new(0.2, 0),
				TopLeftRadius = UDim.new(0.2, 0),
				TopRightRadius = UDim.new(0.2, 0),
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(0.9, 0.5),
				Text = "Weekly",
				TextColor3 = Color3.fromRGB(241, 194, 179),
				TextScaled = true,
				TextStrokeTransparency = 0.8,
				TextWrapped = true,
			}),
			scope:New("UIStroke")({
				Color = Color3.fromRGB(91, 51, 44),
				Thickness = 3,
			}),
		},
	}) :: any
end
