--!strict
--[[
	GENERATED v2 from the legacy place (StarterGui.Storage > Frame > Unlock7): static structure only.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element;
	its logic still has to be rewritten as state bound to this tree.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): Frame
	return scope:New("Frame")({
		Name = "Unlock7",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(37, 45, 90),
		BackgroundTransparency = 0.7,
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		BorderSizePixel = 1,
		Position = UDim2.fromScale(0.2, 0.69),
		Size = UDim2.fromScale(0.11, 0.3),
		-- legacy behaviour: UnlockS (LocalScript, 18 lines)
		[Children] = {
			scope:New("UICorner")({
				BottomLeftRadius = UDim.new(0.15, 0),
				BottomRightRadius = UDim.new(0.15, 0),
				TopLeftRadius = UDim.new(0.15, 0),
				TopRightRadius = UDim.new(0.15, 0),
			}),
			scope:New("TextButton")({
				Name = "Confirm",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(118, 255, 103),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.8),
				Size = UDim2.fromScale(0.8, 0.4),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				Text = "CONFIRM",
				TextSize = 18,
				TextStrokeTransparency = 0.9,
				TextWrapped = true,
				Visible = false,
				[Children] = {
					scope:New("UICorner")({
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),
				},
			}),
			scope:New("TextButton")({
				Name = "Decline",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(255, 107, 107),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromScale(0.8, 0.4),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				Text = "DECLINE",
				TextSize = 18,
				TextStrokeTransparency = 0.9,
				TextWrapped = true,
				Visible = false,
				[Children] = {
					scope:New("UICorner")({
						BottomLeftRadius = UDim.new(0.2, 0),
						BottomRightRadius = UDim.new(0.2, 0),
						TopLeftRadius = UDim.new(0.2, 0),
						TopRightRadius = UDim.new(0.2, 0),
					}),
				},
			}),
			scope:New("TextButton")({
				Name = "Unlock",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = true,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromScale(0.8, 0.5),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
				Text = "UNLOCK",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextSize = 18,
				TextStrokeTransparency = 0.9,
				TextWrapped = true,
			}),
			scope:New("TextLabel")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.fromScale(1, 0.2),
				Text = "500",
				TextColor3 = Color3.fromRGB(126, 255, 255),
				TextScaled = true,
				TextSize = 30,
				TextStrokeTransparency = 0.7,
				TextWrapped = true,
				[Children] = {
					scope:New("ImageLabel")({
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://1954296071",
						Position = UDim2.fromScale(0.5, 1),
						Size = UDim2.fromScale(0.4, 0.4),
						SizeConstraint = Enum.SizeConstraint.RelativeXX,
					}),
				},
			}),
		},
	}) :: any
end
