--!strict
--[[
	GENERATED v2 from ReplicatedStorage.Assets.Models.World.Stored.FromServerScripts.etc.Mods / Testers.Cache.Admin in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Admin",
		ResetOnSpawn = true,
		[Children] = {
			scope:New("TextButton")({
				Name = "Button",
				AutoButtonColor = true,
				BackgroundColor3 = Color3.fromRGB(12, 23, 35),
				FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic),
				Position = UDim2.fromScale(0.0132, 0.4293),
				Size = UDim2.fromOffset(140, 30),
				Text = "Admin",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextWrapped = true,
				[Children] = {
					scope:New("UICorner")({
					}),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						BorderStrokePosition = Enum.BorderStrokePosition.Center,
						Thickness = 3,
					}),
				},
			}),
			scope:New("Frame")({
				Name = "Main",
				BackgroundColor3 = Color3.fromRGB(19, 39, 58),
				BackgroundTransparency = 0.5,
				Position = UDim2.fromScale(0.7198, 0.1743),
				Size = UDim2.fromOffset(500, 750),
				ZIndex = 50,
				[Children] = {
					scope:New("UICorner")({
					}),
					scope:New("TextLabel")({
						Name = "Title",
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0, -0.0893),
						Size = UDim2.fromScale(1, 0.0893),
						Text = "Admin",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextSize = 50,
						TextWrapped = true,
						[Children] = {
							scope:New("UIStroke")({
								Thickness = 2,
							}),
						},
					}),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = 2,
					}),
					scope:New("Folder")({
						Name = "Tabs",
						[Children] = {
							scope:New("TextButton")({
								Name = "Players",
								AutoButtonColor = true,
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(-0.4, 0.0347),
								Rotation = -5,
								Size = UDim2.fromOffset(200, 50),
								Text = "Players",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextWrapped = true,
								[Children] = {
									scope:New("UIStroke")({
										Thickness = 1.5,
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "Server",
								AutoButtonColor = true,
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(-0.4, 0.1013),
								Rotation = -5,
								Size = UDim2.fromOffset(200, 50),
								Text = "Server",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextWrapped = true,
								[Children] = {
									scope:New("UIStroke")({
										Thickness = 1.5,
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "Mysc",
								AutoButtonColor = true,
								BackgroundTransparency = 1,
								FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(-0.4, 0.168),
								Rotation = -5,
								Size = UDim2.fromOffset(200, 50),
								Text = "Mysc",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextWrapped = true,
								[Children] = {
									scope:New("UIStroke")({
										Thickness = 1.5,
									}),
								},
							}),
						},
					}),
					scope:New("Folder")({
						Name = "Sections",
						[Children] = {
							scope:New("ScrollingFrame")({
								Name = "Players",
								Active = true,
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(255, 255, 255),
								Position = UDim2.fromScale(0.014, 0.008),
								ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
								ScrollBarThickness = 6,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								Size = UDim2.fromOffset(488, 737),
								[Children] = {
									scope:New("Frame")({
										Name = "Players",
										BackgroundTransparency = 1,
										Size = UDim2.new(0.959, 0, 0, 500),
										[Children] = {
											scope:New("UICorner")({
											}),
											scope:New("ScrollingFrame")({
												Name = "PlayersList",
												Active = true,
												BackgroundTransparency = 1,
												Position = UDim2.fromScale(0.0168, 0.0945),
												ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
												ScrollBarThickness = 6,
												ScrollingDirection = Enum.ScrollingDirection.Y,
												Size = UDim2.fromOffset(450, 445),
												VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
												[Children] = {
													scope:New("Frame")({
														Name = "PlayerFrame",
														BackgroundColor3 = Color3.fromRGB(0, 0, 0),
														Position = UDim2.fromScale(0.025, 0),
														Size = UDim2.fromScale(0.95, 0.03),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
																BorderStrokePosition = Enum.BorderStrokePosition.Inner,
																Color = Color3.fromRGB(255, 255, 255),
																Enabled = false,
																Thickness = 2,
															}),
															scope:New("TextLabel")({
																Name = "PlayerTags",
																BackgroundTransparency = 1,
																FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
																Size = UDim2.fromScale(1, 0.9),
																Text = "nug ~ @NoUselessGuns ~ 7198934556",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextWrapped = true,
															}),
														},
													}),
													scope:New("UIListLayout")({
														HorizontalAlignment = Enum.HorizontalAlignment.Right,
														Padding = UDim.new(0, 5),
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "Title",
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
												Size = UDim2.fromScale(1, 0.075),
												Text = "Players",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextWrapped = true,
												[Children] = {
													scope:New("UIStroke")({
													}),
												},
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												BorderStrokePosition = Enum.BorderStrokePosition.Inner,
												Thickness = 2,
											}),
										},
									}),
									scope:New("UIListLayout")({
										Padding = UDim.new(0, 15),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									scope:New("Frame")({
										Name = "Data",
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0, 0.1459),
										Size = UDim2.new(0.959, 0, 0.1967, 200),
										[Children] = {
											scope:New("TextLabel")({
												Name = "Title",
												BackgroundTransparency = 1,
												FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
												Size = UDim2.fromScale(1, 0.075),
												Text = "Data",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextWrapped = true,
												[Children] = {
													scope:New("UIStroke")({
													}),
												},
											}),
											scope:New("UICorner")({
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
												BorderStrokePosition = Enum.BorderStrokePosition.Inner,
												Thickness = 2,
											}),
											scope:New("ScrollingFrame")({
												Name = "DataList",
												Active = true,
												BackgroundTransparency = 1,
												Position = UDim2.fromScale(0.0168, 0.0945),
												ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
												ScrollBarThickness = 6,
												ScrollingDirection = Enum.ScrollingDirection.Y,
												Size = UDim2.fromOffset(450, 445),
												VerticalScrollBarPosition = Enum.VerticalScrollBarPosition.Left,
												[Children] = {
													scope:New("Frame")({
														Name = "DataValueFrame",
														BackgroundColor3 = Color3.fromRGB(0, 0, 0),
														Position = UDim2.fromScale(0.025, 0),
														Size = UDim2.fromScale(0.95, 0.03),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
																BorderStrokePosition = Enum.BorderStrokePosition.Inner,
																Color = Color3.fromRGB(255, 255, 255),
																Enabled = false,
																Thickness = 2,
															}),
															scope:New("TextLabel")({
																Name = "Value",
																BackgroundTransparency = 1,
																FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
																Size = UDim2.fromScale(1, 0.9),
																Text = "DevilFruit: Smoke",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextWrapped = true,
															}),
														},
													}),
													scope:New("UIListLayout")({
														HorizontalAlignment = Enum.HorizontalAlignment.Right,
														Padding = UDim.new(0, 5),
													}),
												},
											}),
										},
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
