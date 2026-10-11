--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.MenuNew > Frame > H): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): TextButton
	return scope:New("TextButton")({
		Name = "H",
		AutoButtonColor = true,
		BackgroundTransparency = 0.85,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 1,
		Position = UDim2.fromScale(0.05, -0.53),
		Size = UDim2.fromScale(0.9, 0.15),
		Text = "Challenges",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextScaled = true,
		TextStrokeTransparency = 0.6,
		TextWrapped = true,
		ZIndex = 2,
		-- legacy behaviour: LocalScript (LocalScript, 12 lines)
		[Children] = {
			scope:New("ImageLabel")({
				Name = "Alert",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 23, 23),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				ImageColor3 = Color3.fromRGB(255, 0, 0),
				Position = UDim2.fromScale(1.05, 0.5),
				Size = UDim2.fromScale(0.72, 0.48),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				ZIndex = 2,
				[Children] = {
					scope:New("TextLabel")({
						Name = "Quantity",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.9),
						Text = "99+",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextWrapped = true,
						ZIndex = 2,
					}),
					scope:New("UICorner")({
						BottomLeftRadius = UDim.new(0.4, 0),
						BottomRightRadius = UDim.new(0.4, 0),
						TopLeftRadius = UDim.new(0.4, 0),
						TopRightRadius = UDim.new(0.4, 0),
					}),
				},
			}),
			scope:New("ImageLabel")({
				Name = "ImageLabels",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Image = "rbxassetid://1012758197",
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
			}),
		},
	}) :: any
end
