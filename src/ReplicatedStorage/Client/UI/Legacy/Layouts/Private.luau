--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Private in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Private",
		Enabled = false,
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				Name = "Main",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(73, 138, 234),
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.4, 0.6),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				[Children] = {
					scope:New("UICorner")({
						BottomLeftRadius = UDim.new(0, 10),
						BottomRightRadius = UDim.new(0, 10),
						TopLeftRadius = UDim.new(0, 10),
						TopRightRadius = UDim.new(0, 10),
					}),
					scope:New("Frame")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(179, 219, 255),
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.925, 0.95),
						-- legacy behaviour: PrivateMain (LocalScript, 38 lines)
						[Children] = {
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(0, 10),
								BottomRightRadius = UDim.new(0, 10),
								TopLeftRadius = UDim.new(0, 10),
								TopRightRadius = UDim.new(0, 10),
							}),
							scope:New("TextButton")({
								Name = "Generate",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(74, 153, 255),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.5, 0.275),
								Size = UDim2.fromScale(0.8, 0.15),
								SizeConstraint = Enum.SizeConstraint.RelativeXX,
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Generate",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 20,
								TextStrokeTransparency = 0.7,
							}),
							scope:New("TextButton")({
								Name = "Buy",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(74, 153, 255),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.5, 0.425),
								Size = UDim2.fromScale(0.8, 0.15),
								SizeConstraint = Enum.SizeConstraint.RelativeXX,
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Buy 30 Days",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 20,
								TextStrokeTransparency = 0.7,
							}),
							scope:New("TextButton")({
								Name = "Join",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(74, 153, 255),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.5, 0.8727),
								Size = UDim2.fromScale(0.8, 0.15),
								SizeConstraint = Enum.SizeConstraint.RelativeXX,
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Join",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 20,
								TextStrokeTransparency = 0.7,
							}),
							scope:New("TextBox")({
								Name = "YourCode",
								BackgroundColor3 = Color3.fromRGB(74, 153, 255),
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
								Position = UDim2.fromScale(0.1018, 0.0762),
								Size = UDim2.fromScale(0.8, 0.0975),
								Text = "None",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextEditable = false,
								TextSize = 20,
								TextStrokeTransparency = 0.7,
								[Children] = {
									scope:New("UICorner")({
									}),
								},
							}),
							scope:New("TextBox")({
								Name = "JoinCode",
								BackgroundColor3 = Color3.fromRGB(74, 153, 255),
								ClearTextOnFocus = true,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
								Position = UDim2.fromScale(0.1018, 0.672),
								Size = UDim2.fromScale(0.8, 0.0975),
								Text = "Enter Code",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextSize = 20,
								TextStrokeTransparency = 0.7,
								[Children] = {
									scope:New("UICorner")({
									}),
								},
							}),
							scope:New("TextBox")({
								Name = "DaysLeft",
								BackgroundColor3 = Color3.fromRGB(74, 153, 255),
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Interactable = false,
								PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
								Position = UDim2.fromScale(0.1018, 0.45),
								Size = UDim2.fromScale(0.8, 0.0975),
								Text = "0 Days Left",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextEditable = false,
								TextSize = 20,
								TextStrokeTransparency = 0.7,
								[Children] = {
									scope:New("UICorner")({
									}),
								},
							}),
						},
					}),
				},
			}),
			scope:New("TextButton")({
				Name = "MainMenuButton",
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutoButtonColor = true,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				BorderSizePixel = 1,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				Position = UDim2.fromScale(0.5, 0.1),
				Size = UDim2.fromScale(0.3, 0.075),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
				Text = "Main Menu",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				TextStrokeTransparency = 0.7,
				TextWrapped = true,
			}),
		},
	}) :: any
end
