--!strict
--[[
	GENERATED v2 from Workspace.Merchants.LegendaryHero.Clickable.InviteRaid in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "InviteRaid",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("Frame")({
				Name = "InviteFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				[Children] = {
					scope:New("StringValue")({
						Name = "Owner",
					}),
					scope:New("Frame")({
						Name = "InviteFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.2162),
						Size = UDim2.fromScale(0.3, 0.1664),
						[Children] = {
							scope:New("Frame")({
								Name = "DeclineButtonFrame",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.6983, 0.7753),
								Size = UDim2.fromScale(0.2773, 0.3),
								ZIndex = 10,
								[Children] = {
									scope:New("ImageLabel")({
										Name = "Background",
										AnchorPoint = Vector2.new(0.5, 0.5),
										Image = "rbxassetid://100570812821023",
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1),
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
											scope:New("UIStroke")({
												Color = Color3.fromRGB(255, 255, 255),
											}),
										},
									}),
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 2.7443,
									}),
									scope:New("TextButton")({
										Name = "DeclineButton",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BackgroundColor3 = Color3.fromRGB(255, 0, 0),
										BackgroundTransparency = 0.4,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.875, 0.75),
										Text = "Decline",
										TextScaled = true,
										TextWrapped = true,
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 6),
												BottomRightRadius = UDim.new(0, 6),
												TopLeftRadius = UDim.new(0, 6),
												TopRightRadius = UDim.new(0, 6),
											}),
										},
									}),
								},
							}),
							scope:New("Frame")({
								Name = "AcceptButtonFrame",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.2991, 0.7628),
								Size = UDim2.fromScale(0.2773, 0.3),
								ZIndex = 10,
								[Children] = {
									scope:New("ImageLabel")({
										Name = "Background",
										AnchorPoint = Vector2.new(0.5, 0.5),
										Image = "rbxassetid://100570812821023",
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1),
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
											scope:New("UIStroke")({
												Color = Color3.fromRGB(255, 255, 255),
											}),
										},
									}),
									scope:New("TextButton")({
										Name = "AcceptButton",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BackgroundColor3 = Color3.fromRGB(0, 255, 0),
										BackgroundTransparency = 0.4,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.875, 0.75),
										Text = "Accept",
										TextScaled = true,
										TextWrapped = true,
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 6),
												BottomRightRadius = UDim.new(0, 6),
												TopLeftRadius = UDim.new(0, 6),
												TopRightRadius = UDim.new(0, 6),
											}),
										},
									}),
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 2.7443,
									}),
								},
							}),
							scope:New("TextBox")({
								Name = "InviteText",
								BackgroundTransparency = 0.4,
								ClearTextOnFocus = true,
								PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
								Position = UDim2.fromScale(0.0271, 0.0363),
								Size = UDim2.fromScale(0.9397, 0.4958),
								Text = "Invite From PlayerName to MinigameName",
								TextScaled = true,
								TextWrapped = true,
								ZIndex = 10,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 10),
										BottomRightRadius = UDim.new(0, 10),
										TopLeftRadius = UDim.new(0, 10),
										TopRightRadius = UDim.new(0, 10),
									}),
								},
							}),
							scope:New("ImageLabel")({
								Name = "Background",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ZIndex = 3,
								[Children] = {
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 10),
										BottomRightRadius = UDim.new(0, 10),
										TopLeftRadius = UDim.new(0, 10),
										TopRightRadius = UDim.new(0, 10),
									}),
									scope:New("UIStroke")({
										Color = Color3.fromRGB(255, 255, 255),
										Thickness = 2,
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 2.969,
							}),
						},
					}),
					scope:New("StringValue")({
						Name = "Quest",
					}),
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1.6466,
					}),
				},
			}),
		},
	}) :: any
end
