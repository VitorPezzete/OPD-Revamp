--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Storage > Frame > TextLabel): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): TextLabel
	return scope:New("TextLabel")({
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 1,
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 0.08),
		Text = "Devil Fruit Storage",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeTransparency = 0.7,
		TextWrapped = true,
	}) :: any
end
