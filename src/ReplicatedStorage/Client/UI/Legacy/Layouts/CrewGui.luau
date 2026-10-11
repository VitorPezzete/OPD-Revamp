--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.CrewGui in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "CrewGui",
		ResetOnSpawn = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		[Children] = {
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.7),
				Visible = false,
				-- legacy behaviour: CrewsHandler (LocalScript, 190 lines)
				[Children] = {
					scope:New("ImageLabel")({
						Name = "ImageLabels",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://100570812821023",
						ImageTransparency = 0.11,
						LayoutOrder = -3,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						[Children] = {
							scope:New("UIStroke")({
							}),
							scope:New("UICorner")({
							}),
						},
					}),
					scope:New("TextLabel")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 0.7,
						Position = UDim2.fromScale(0.5, 0.07),
						Size = UDim2.fromScale(0.95, 0.1),
						Text = "Crew Menu",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.4,
						TextWrapped = true,
						ZIndex = 2,
						[Children] = {
							scope:New("UICorner")({
							}),
							scope:New("UIStroke")({
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "CreateFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5594),
						Size = UDim2.fromScale(0.8, 0.7),
						Visible = false,
						[Children] = {
							scope:New("TextButton")({
								Name = "CreateButton",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(0, 255, 0),
								BackgroundTransparency = 0.3,
								Position = UDim2.fromScale(0.495, 0.8555),
								Size = UDim2.fromScale(0.429, 0.1653),
								Text = "Create",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.4,
								TextWrapped = true,
								ZIndex = 2,
								[Children] = {
									scope:New("UICorner")({
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
									scope:New("TextLabel")({
										Name = "GemDisplayLabel",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(1.2413, 0.5),
										Size = UDim2.fromScale(0.4157, 1.011),
										Text = "2500",
										TextColor3 = Color3.fromRGB(85, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0,
										TextWrapped = true,
										TextXAlignment = Enum.TextXAlignment.Right,
										[Children] = {
											scope:New("ImageLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(83, 45, 149),
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												Image = "rbxassetid://1954296071",
												Position = UDim2.fromScale(1.278, 0.55),
												ScaleType = Enum.ScaleType.Fit,
												Size = UDim2.fromScale(0.556, 1.1),
											}),
										},
									}),
								},
							}),
							scope:New("ImageLabel")({
								Name = "ImageLabels",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Image = "rbxassetid://100570812821023",
								ImageTransparency = 0.15,
								LayoutOrder = -3,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								[Children] = {
									scope:New("UIStroke")({
									}),
									scope:New("UICorner")({
									}),
								},
							}),
							scope:New("TextBox")({
								Name = "GroupID",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 0.25,
								ClearTextOnFocus = true,
								PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
								Position = UDim2.fromScale(0.498, 0.3013),
								Size = UDim2.fromScale(0.5, 0.15),
								Text = "Insert your image ID",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.4,
								TextWrapped = true,
								[Children] = {
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.6,
										Position = UDim2.fromScale(0.4948, -0.561),
										Size = UDim2.fromScale(0.9274, 0.7706),
										Text = "Image ID",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.4,
										TextWrapped = true,
										[Children] = {
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
											scope:New("UICorner")({
											}),
										},
									}),
									scope:New("UICorner")({
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
								},
							}),
							scope:New("TextBox")({
								Name = "CrewName",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 0.25,
								ClearTextOnFocus = true,
								PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
								Position = UDim2.fromScale(0.498, 0.6254),
								Size = UDim2.fromScale(0.5, 0.15),
								Text = "Insert your crew name",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.4,
								TextWrapped = true,
								[Children] = {
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.6,
										Position = UDim2.fromScale(0.4948, -0.561),
										Size = UDim2.fromScale(0.9274, 0.7706),
										Text = "Crew Name",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.4,
										TextWrapped = true,
										[Children] = {
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
											scope:New("UICorner")({
											}),
										},
									}),
									scope:New("UICorner")({
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
								},
							}),
							scope:New("Frame")({
								Name = "ConfirmFrame",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								Visible = false,
								ZIndex = 10,
								[Children] = {
									scope:New("ImageLabel")({
										Name = "ImageLabels",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(0, 0, 0),
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										Image = "rbxassetid://100570812821023",
										ImageTransparency = 0.15,
										LayoutOrder = -3,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1),
										ZIndex = 9,
										[Children] = {
											scope:New("UIStroke")({
											}),
											scope:New("UICorner")({
											}),
										},
									}),
									scope:New("TextButton")({
										Name = "Confirm",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BackgroundColor3 = Color3.fromRGB(0, 255, 0),
										BackgroundTransparency = 0.3,
										Position = UDim2.fromScale(0.2612, 0.8505),
										Size = UDim2.fromScale(0.429, 0.1653),
										Text = "Confirm",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.4,
										TextWrapped = true,
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
										},
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 0.6,
										Position = UDim2.fromScale(0.5, 0.3721),
										Size = UDim2.fromScale(0.9, 0.6608),
										Text = "Do you want to join the CrewName crew?",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.4,
										TextWrapped = true,
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
											}),
										},
									}),
									scope:New("TextButton")({
										Name = "Decline",
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BackgroundColor3 = Color3.fromRGB(255, 0, 0),
										BackgroundTransparency = 0.45,
										LayoutOrder = 10,
										Position = UDim2.fromScale(0.734, 0.85),
										Size = UDim2.fromScale(0.429, 0.165),
										Text = "Decline",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.4,
										TextWrapped = true,
										ZIndex = 10,
										[Children] = {
											scope:New("UICorner")({
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
										},
									}),
								},
							}),
						},
					}),
					scope:New("Frame")({
						Name = "InCrewFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.1306, 0.5475),
						Size = UDim2.fromScale(0.2118, 0.7999),
						ZIndex = 2,
						[Children] = {
							scope:New("UIListLayout")({
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
								Padding = UDim.new(0, 3),
								SortOrder = Enum.SortOrder.LayoutOrder,
								VerticalAlignment = Enum.VerticalAlignment.Center,
							}),
							scope:New("ImageButton")({
								Name = "MenuButton",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								Image = "rbxassetid://1012758197",
								ImageTransparency = 0.6,
								LayoutOrder = 1,
								Position = UDim2.fromScale(0.5, 3.7),
								Size = UDim2.fromScale(0.95, 0.15),
								[Children] = {
									scope:New("Frame")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(2.8871, 1.5681),
										Size = UDim2.fromScale(3.6196, 6.3539),
										Visible = false,
										[Children] = {
											scope:New("ImageLabel")({
												Name = "CrewImage",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,
												Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
												Position = UDim2.fromScale(0.2295, 0.5009),
												Size = UDim2.fromScale(0.4657, 0.6622),
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "CrewBounty",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(255, 85, 0),
												BackgroundTransparency = 0.6,
												BorderColor3 = Color3.fromRGB(255, 255, 255),
												Position = UDim2.fromScale(0.2298, 0.9349),
												Size = UDim2.fromScale(0.4651, 0.1519),
												Text = "Crew Bounty: x.xxx.xxx.xxx",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												Visible = false,
												ZIndex = 2,
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "CrewName",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(255, 255, 0),
												BackgroundTransparency = 0.6,
												BorderColor3 = Color3.fromRGB(255, 255, 255),
												Position = UDim2.fromScale(0.227, 0.095),
												Size = UDim2.fromScale(0.466, 0.121),
												Text = "CrewName",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												ZIndex = 2,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "CrewLvL",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(64, 255, 64),
												BackgroundTransparency = 0.6,
												BorderColor3 = Color3.fromRGB(255, 255, 255),
												Position = UDim2.fromScale(0.6152, 0.095),
												Size = UDim2.fromScale(0.2249, 0.121),
												Text = "Level: 0",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												ZIndex = 2,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "CrewXp",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.6,
												BorderColor3 = Color3.fromRGB(255, 255, 255),
												Position = UDim2.fromScale(0.8759, 0.095),
												Size = UDim2.fromScale(0.2432, 0.121),
												Text = "0/508",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												ZIndex = 2,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("Frame")({
												Name = "Bar",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												Position = UDim2.fromScale(0.7501, 0.2298),
												Size = UDim2.fromScale(0.4947, 0.0468),
												SizeConstraint = Enum.SizeConstraint.RelativeXX,
												[Children] = {
													scope:New("ImageLabel")({
														Name = "Back",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundColor3 = Color3.fromRGB(0, 0, 0),
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														[Children] = {
															scope:New("UICorner")({
																BottomLeftRadius = UDim.new(0.5, 0),
																BottomRightRadius = UDim.new(0.5, 0),
																TopLeftRadius = UDim.new(0.5, 0),
																TopRightRadius = UDim.new(0.5, 0),
															}),
														},
													}),
													scope:New("ImageLabel")({
														Name = "Front",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundColor3 = Color3.fromRGB(64, 255, 64),
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														Position = UDim2.fromScale(0.0404, 0.5),
														Size = UDim2.fromScale(0.0897, 0.9321),
														[Children] = {
															scope:New("UICorner")({
																BottomLeftRadius = UDim.new(0.5, 0),
																BottomRightRadius = UDim.new(0.5, 0),
																TopLeftRadius = UDim.new(0.5, 0),
																TopRightRadius = UDim.new(0.5, 0),
															}),
														},
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
												Position = UDim2.fromScale(0.23, 0.935),
												Size = UDim2.fromScale(0.465, 0.152),
												Visible = false,
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
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
												Position = UDim2.fromScale(0.227, 0.095),
												Size = UDim2.fromScale(0.466, 0.121),
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
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
												Position = UDim2.fromScale(0.8755, 0.0946),
												Size = UDim2.fromScale(0.243, 0.1212),
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
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
												Position = UDim2.fromScale(0.6155, 0.0946),
												Size = UDim2.fromScale(0.225, 0.1212),
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
													}),
												},
											}),
										},
									}),
									scope:New("UICorner")({
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1.0034),
										Text = "Menu",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.2,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("ImageButton")({
								Name = "Players",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								Image = "rbxassetid://1012758197",
								ImageTransparency = 0.6,
								LayoutOrder = 2,
								Position = UDim2.fromScale(0.5, 3.7),
								Size = UDim2.fromScale(0.95, 0.15),
								[Children] = {
									scope:New("Frame")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(2.8871, 0.4797),
										Size = UDim2.fromScale(3.6196, 6.3395),
										Visible = false,
										[Children] = {
											scope:New("ScrollingFrame")({
												Active = true,
												AutomaticCanvasSize = Enum.AutomaticSize.XY,
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.9,
												Position = UDim2.fromScale(0, 0.112),
												ScrollBarThickness = 0,
												Size = UDim2.fromScale(0.6548, 0.8863),
												[Children] = {
													scope:New("UIListLayout")({
														Padding = UDim.new(0, 3),
														SortOrder = Enum.SortOrder.LayoutOrder,
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("Frame")({
														Name = "Template",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Size = UDim2.fromScale(1, 0.15),
														Visible = false,
														[Children] = {
															scope:New("TextButton")({
																Name = "PlayerName",
																AnchorPoint = Vector2.new(0.5, 0.5),
																AutoButtonColor = true,
																BackgroundTransparency = 0.6,
																LayoutOrder = 10,
																Position = UDim2.fromScale(0.3661, 0.5),
																Size = UDim2.fromScale(0.7322, 1),
																Text = "PlayerName",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.4,
																TextWrapped = true,
																ZIndex = 2,
																[Children] = {
																	scope:New("UICorner")({
																	}),
																	scope:New("UIStroke")({
																		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
																	}),
																},
															}),
															scope:New("TextLabel")({
																Name = "RoleName",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundColor3 = Color3.fromRGB(0, 255, 234),
																BackgroundTransparency = 0.6,
																Position = UDim2.fromScale(0.87, 0.5),
																Size = UDim2.fromScale(0.2427, 1),
																Text = "RoleName",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.4,
																TextWrapped = true,
																ZIndex = 2,
																[Children] = {
																	scope:New("UICorner")({
																	}),
																	scope:New("UIStroke")({
																		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
																Position = UDim2.fromScale(0.366, 0.5),
																Size = UDim2.fromScale(0.732, 1),
																[Children] = {
																	scope:New("UIStroke")({
																		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
																	}),
																	scope:New("UICorner")({
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
																Position = UDim2.fromScale(0.87, 0.5),
																Size = UDim2.fromScale(0.243, 1),
																[Children] = {
																	scope:New("UIStroke")({
																		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
																	}),
																	scope:New("UICorner")({
																	}),
																},
															}),
														},
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "MembersNumber",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.6,
												Position = UDim2.fromScale(0.3247, 0.0599),
												Size = UDim2.fromScale(0.4058, 0.093),
												Text = "1/10",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												ZIndex = 2,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("TextLabel")({
												Name = "PlayerName",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 1,
												Position = UDim2.fromScale(0.8279, 0.1563),
												Size = UDim2.fromScale(0.3084, 0.093),
												Text = "SelectedPlayerName",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												ZIndex = 2,
												[Children] = {
													scope:New("ImageButton")({
														Name = "Promote",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(85, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 1.6),
														Size = UDim2.fromScale(0.9, 0.9),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Promote",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "Kick",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(255, 0, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 2.65),
														Size = UDim2.fromScale(0.9, 0.9),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Kick",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "Demote",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(255, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 3.7),
														Size = UDim2.fromScale(0.9, 0.9),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Demote",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "ConfirmTemplate",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.15,
												LayoutOrder = 10,
												Position = UDim2.fromScale(0.4655, 0.4395),
												Size = UDim2.fromScale(0.569, 0.379),
												Visible = false,
												ZIndex = 10,
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 0.4,
														Position = UDim2.fromScale(0.4963, 0.3439),
														Size = UDim2.fromScale(0.9046, 0.5456),
														Text = "Are you sure you want to dos this action?",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.27,
														TextWrapped = true,
														ZIndex = 10,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("ImageLabel")({
														Name = "ImageLabels",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundColor3 = Color3.fromRGB(0, 0, 0),
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Image = "rbxassetid://100570812821023",
														ImageTransparency = 0.11,
														LayoutOrder = -3,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														ZIndex = 9,
														[Children] = {
															scope:New("UIStroke")({
															}),
															scope:New("UICorner")({
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "No",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(255, 0, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.745, 0.833),
														Size = UDim2.fromScale(0.4, 0.23),
														ZIndex = 10,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1),
																Text = "No",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "Yes",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(85, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.243, 0.833),
														Size = UDim2.fromScale(0.4, 0.23),
														ZIndex = 10,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1),
																Text = "Yes",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
														},
													}),
												},
											}),
											scope:New("TextBox")({
												Name = "PlayerTextBox",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.7,
												ClearTextOnFocus = true,
												PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
												Position = UDim2.fromScale(0.828, 0.826),
												Size = UDim2.fromScale(0.308, 0.093),
												Text = "Player Name",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextStrokeTransparency = 0.2,
												[Children] = {
													scope:New("ImageButton")({
														Name = "Invite",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(85, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 1.6),
														Size = UDim2.fromScale(0.9, 0.9),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Invite",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
														},
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
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
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.325, 0.06),
												Size = UDim2.fromScale(0.406, 0.093),
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
													}),
												},
											}),
											scope:New("ImageLabel")({
												Name = "ImageLabels",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.828, 0.156),
												Size = UDim2.fromScale(0.308, 0.093),
												[Children] = {
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("UICorner")({
													}),
												},
											}),
										},
									}),
									scope:New("UICorner")({
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1.0034),
										Text = "Players",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.2,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("ImageButton")({
								Name = "Upgrades",
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								Image = "rbxassetid://1012758197",
								ImageTransparency = 0.6,
								LayoutOrder = 3,
								Position = UDim2.fromScale(0.5, 3.7),
								Size = UDim2.fromScale(0.95, 0.15),
								[Children] = {
									scope:New("Frame")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										ClipsDescendants = true,
										Position = UDim2.fromScale(2.8871, -0.5807),
										Size = UDim2.fromScale(3.6196, 6.3395),
										Visible = false,
										[Children] = {
											scope:New("Frame")({
												Name = "LogoVisible",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.7,
												LayoutOrder = 2,
												Position = UDim2.fromScale(0.2273, 0.246),
												Size = UDim2.fromScale(0.7, 0.4),
												Visible = false,
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(0, 255, 0),
														BackgroundTransparency = 0.45,
														LayoutOrder = 10,
														Position = UDim2.fromScale(0.2835, 0.8214),
														Size = UDim2.fromScale(0.4671, 0.2304),
														Text = "Buy",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.4,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																Name = "GemDisplayLabel",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(1.3035, 0.4654),
																Size = UDim2.fromScale(0.6069, 1.011),
																Text = "???",
																TextColor3 = Color3.fromRGB(85, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0,
																TextWrapped = true,
																TextXAlignment = Enum.TextXAlignment.Right,
																[Children] = {
																	scope:New("ImageLabel")({
																		AnchorPoint = Vector2.new(0.5, 0.5),
																		BackgroundColor3 = Color3.fromRGB(83, 45, 149),
																		BackgroundTransparency = 1,
																		BorderColor3 = Color3.fromRGB(27, 42, 53),
																		Image = "rbxassetid://1954296071",
																		Position = UDim2.fromScale(1.3331, 0.55),
																		ScaleType = Enum.ScaleType.Fit,
																		Size = UDim2.fromScale(0.6713, 1.1),
																	}),
																},
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														Position = UDim2.fromScale(0.4938, 0.3454),
														Size = UDim2.fromScale(0.9, 0.548),
														Text = "Make crew logo visible on player leaderboard",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
												},
											}),
											scope:New("UIGridLayout")({
												CellPadding = UDim2.fromScale(0.015, 0.015),
												CellSize = UDim2.fromScale(0.7, 0.4),
												HorizontalAlignment = Enum.HorizontalAlignment.Center,
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),
											scope:New("Frame")({
												Name = "UpgradeCapacity",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.7,
												LayoutOrder = 1,
												Position = UDim2.fromScale(0.2273, 0.246),
												Size = UDim2.fromScale(0.7, 0.4),
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														Position = UDim2.fromScale(0.4938, 0.3454),
														Size = UDim2.fromScale(0.9, 0.548),
														Text = "Crew Member Slots 10 -> 11",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("ImageLabel")({
														Name = "ImageLabels",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														ZIndex = 0,
														[Children] = {
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("UICorner")({
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "Promote",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(85, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.284, 0.821),
														Size = UDim2.fromScale(0.467, 0.23),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Upgrade",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
															scope:New("TextLabel")({
																Name = "GemDisplayLabel",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(1.3035, 0.4654),
																Size = UDim2.fromScale(0.6069, 1.011),
																Text = "???",
																TextColor3 = Color3.fromRGB(85, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
																TextXAlignment = Enum.TextXAlignment.Right,
																[Children] = {
																	scope:New("ImageLabel")({
																		AnchorPoint = Vector2.new(0.5, 0.5),
																		BackgroundColor3 = Color3.fromRGB(83, 45, 149),
																		BackgroundTransparency = 1,
																		BorderColor3 = Color3.fromRGB(27, 42, 53),
																		Image = "rbxassetid://1954296071",
																		Position = UDim2.fromScale(1.3331, 0.55),
																		ScaleType = Enum.ScaleType.Fit,
																		Size = UDim2.fromScale(0.6713, 1.1),
																	}),
																},
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "BuyCrewBase",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.7,
												LayoutOrder = 3,
												Position = UDim2.fromScale(0.2273, 0.246),
												Size = UDim2.fromScale(0.7, 0.4),
												Visible = false,
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														Position = UDim2.fromScale(0.4938, 0.3454),
														Size = UDim2.fromScale(0.9, 0.548),
														Text = "Acess to Crew Base",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
													scope:New("TextButton")({
														Name = "Buy",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(0, 255, 0),
														BackgroundTransparency = 0.45,
														LayoutOrder = 10,
														Position = UDim2.fromScale(0.2835, 0.8214),
														Size = UDim2.fromScale(0.4671, 0.2304),
														Text = "Buy",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.4,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																Name = "GemDisplayLabel",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(1.3035, 0.4654),
																Size = UDim2.fromScale(0.6069, 1.011),
																Text = "???",
																TextColor3 = Color3.fromRGB(85, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0,
																TextWrapped = true,
																TextXAlignment = Enum.TextXAlignment.Right,
																[Children] = {
																	scope:New("ImageLabel")({
																		AnchorPoint = Vector2.new(0.5, 0.5),
																		BackgroundColor3 = Color3.fromRGB(83, 45, 149),
																		BackgroundTransparency = 1,
																		BorderColor3 = Color3.fromRGB(27, 42, 53),
																		Image = "rbxassetid://1954296071",
																		Position = UDim2.fromScale(1.3331, 0.55),
																		ScaleType = Enum.ScaleType.Fit,
																		Size = UDim2.fromScale(0.6713, 1.1),
																	}),
																},
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("Frame")({
												Name = "UpgradeTemplate",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BackgroundTransparency = 0.7,
												LayoutOrder = 10,
												Position = UDim2.fromScale(0.2273, 0.246),
												Size = UDim2.fromScale(0.7, 0.4),
												Visible = false,
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														Position = UDim2.fromScale(0.4938, 0.3454),
														Size = UDim2.fromScale(0.9, 0.548),
														Text = "Upgrade Something",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
													scope:New("TextButton")({
														Name = "Promote",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(0, 255, 0),
														BackgroundTransparency = 0.45,
														LayoutOrder = 10,
														Position = UDim2.fromScale(0.2835, 0.8214),
														Size = UDim2.fromScale(0.4671, 0.2304),
														Text = "Upgrade",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.4,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																Name = "GemDisplayLabel",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(1.3035, 0.4654),
																Size = UDim2.fromScale(0.6069, 1.011),
																Text = "???",
																TextColor3 = Color3.fromRGB(85, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0,
																TextWrapped = true,
																TextXAlignment = Enum.TextXAlignment.Right,
																[Children] = {
																	scope:New("ImageLabel")({
																		AnchorPoint = Vector2.new(0.5, 0.5),
																		BackgroundColor3 = Color3.fromRGB(83, 45, 149),
																		BackgroundTransparency = 1,
																		BorderColor3 = Color3.fromRGB(27, 42, 53),
																		Image = "rbxassetid://1954296071",
																		Position = UDim2.fromScale(1.3331, 0.55),
																		ScaleType = Enum.ScaleType.Fit,
																		Size = UDim2.fromScale(0.6713, 1.1),
																	}),
																},
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("Frame")({
												Name = "ChangeLogo",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.7,
												LayoutOrder = 1,
												Position = UDim2.fromScale(0.2273, 0.246),
												Size = UDim2.fromScale(0.7, 0.4),
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														Position = UDim2.fromScale(0.4938, 0.3454),
														Size = UDim2.fromScale(0.9, 0.548),
														Text = "Change Crew Logo",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("ImageLabel")({
														Name = "ImageLabels",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														ZIndex = 0,
														[Children] = {
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("UICorner")({
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "Promote",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(85, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.284, 0.821),
														Size = UDim2.fromScale(0.467, 0.23),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Upgrade",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
															scope:New("TextLabel")({
																Name = "GemDisplayLabel",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(1.3035, 0.4654),
																Size = UDim2.fromScale(0.6069, 1.011),
																Text = "500",
																TextColor3 = Color3.fromRGB(85, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
																TextXAlignment = Enum.TextXAlignment.Right,
																[Children] = {
																	scope:New("ImageLabel")({
																		AnchorPoint = Vector2.new(0.5, 0.5),
																		BackgroundColor3 = Color3.fromRGB(83, 45, 149),
																		BackgroundTransparency = 1,
																		BorderColor3 = Color3.fromRGB(27, 42, 53),
																		Image = "rbxassetid://1954296071",
																		Position = UDim2.fromScale(1.3331, 0.55),
																		ScaleType = Enum.ScaleType.Fit,
																		Size = UDim2.fromScale(0.6713, 1.1),
																	}),
																},
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "ChangeName",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.7,
												LayoutOrder = 1,
												Position = UDim2.fromScale(0.2273, 0.246),
												Size = UDim2.fromScale(0.7, 0.4),
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														Position = UDim2.fromScale(0.4938, 0.3454),
														Size = UDim2.fromScale(0.9, 0.548),
														Text = "Change Crew Name",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
														},
													}),
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("ImageLabel")({
														Name = "ImageLabels",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														ZIndex = 0,
														[Children] = {
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("UICorner")({
															}),
														},
													}),
													scope:New("ImageButton")({
														Name = "Promote",
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(85, 255, 0),
														Image = "rbxassetid://1012758197",
														ImageTransparency = 0.6,
														Position = UDim2.fromScale(0.284, 0.821),
														Size = UDim2.fromScale(0.467, 0.23),
														[Children] = {
															scope:New("UICorner")({
															}),
															scope:New("UIStroke")({
																ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
															}),
															scope:New("TextLabel")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1, 1.0034),
																Text = "Upgrade",
																TextColor3 = Color3.fromRGB(255, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
															}),
															scope:New("TextLabel")({
																Name = "GemDisplayLabel",
																AnchorPoint = Vector2.new(0.5, 0.5),
																BackgroundTransparency = 1,
																Position = UDim2.fromScale(1.3035, 0.4654),
																Size = UDim2.fromScale(0.6069, 1.011),
																Text = "1000",
																TextColor3 = Color3.fromRGB(85, 255, 255),
																TextScaled = true,
																TextStrokeTransparency = 0.2,
																TextWrapped = true,
																TextXAlignment = Enum.TextXAlignment.Right,
																[Children] = {
																	scope:New("ImageLabel")({
																		AnchorPoint = Vector2.new(0.5, 0.5),
																		BackgroundColor3 = Color3.fromRGB(83, 45, 149),
																		BackgroundTransparency = 1,
																		BorderColor3 = Color3.fromRGB(27, 42, 53),
																		Image = "rbxassetid://1954296071",
																		Position = UDim2.fromScale(1.3331, 0.55),
																		ScaleType = Enum.ScaleType.Fit,
																		Size = UDim2.fromScale(0.6713, 1.1),
																	}),
																},
															}),
														},
													}),
												},
											}),
										},
									}),
									scope:New("Frame")({
										Name = "ConfirmTemplate",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(0, 0, 0),
										BackgroundTransparency = 0.15,
										LayoutOrder = 10,
										Position = UDim2.fromScale(2.6704, -0.8771),
										Size = UDim2.fromScale(2.0546, 2.1328),
										Visible = false,
										[Children] = {
											scope:New("TextLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.4963, 0.3439),
												Size = UDim2.fromScale(0.9046, 0.5456),
												Text = "Are you sure that you want to puchase this upgrade",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("UICorner")({
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
											scope:New("ImageLabel")({
												Name = "ImageLabels",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Image = "rbxassetid://100570812821023",
												ImageTransparency = 0.11,
												LayoutOrder = -3,
												Position = UDim2.fromScale(0.5, 0.5),
												Size = UDim2.fromScale(1, 1),
												ZIndex = 0,
												[Children] = {
													scope:New("UIStroke")({
													}),
													scope:New("UICorner")({
													}),
												},
											}),
											scope:New("ImageButton")({
												Name = "Decline",
												AnchorPoint = Vector2.new(0.5, 0.5),
												AutoButtonColor = true,
												BackgroundColor3 = Color3.fromRGB(85, 255, 0),
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.243, 0.833),
												Size = UDim2.fromScale(0.4, 0.23),
												ZIndex = 10,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "Yes",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
													}),
												},
											}),
											scope:New("ImageButton")({
												Name = "Accept",
												AnchorPoint = Vector2.new(0.5, 0.5),
												AutoButtonColor = true,
												BackgroundColor3 = Color3.fromRGB(255, 0, 0),
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.745, 0.833),
												Size = UDim2.fromScale(0.4, 0.23),
												ZIndex = 10,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "No",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
													}),
												},
											}),
										},
									}),
									scope:New("UICorner")({
									}),
									scope:New("UIStroke")({
										ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
									}),
									scope:New("TextLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundTransparency = 1,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1.0034),
										Text = "Upgrades",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.2,
										TextWrapped = true,
									}),
									scope:New("Frame")({
										Name = "ChangeLogoTemplate",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(0, 0, 0),
										BackgroundTransparency = 0.15,
										LayoutOrder = 10,
										Position = UDim2.fromScale(2.6704, -0.8771),
										Size = UDim2.fromScale(2.0546, 2.1328),
										Visible = false,
										[Children] = {
											scope:New("TextLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.4963, 0.3439),
												Size = UDim2.fromScale(0.9046, 0.5456),
												Text = "Are you sure that you want to puchase this upgrade",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("UICorner")({
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
											scope:New("ImageLabel")({
												Name = "ImageLabels",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Image = "rbxassetid://100570812821023",
												ImageTransparency = 0.11,
												LayoutOrder = -3,
												Position = UDim2.fromScale(0.5, 0.5),
												Size = UDim2.fromScale(1, 1),
												ZIndex = 0,
												[Children] = {
													scope:New("UIStroke")({
													}),
													scope:New("UICorner")({
													}),
												},
											}),
											scope:New("ImageButton")({
												Name = "Confirm",
												AnchorPoint = Vector2.new(0.5, 0.5),
												AutoButtonColor = true,
												BackgroundColor3 = Color3.fromRGB(85, 255, 0),
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.243, 0.833),
												Size = UDim2.fromScale(0.4, 0.23),
												ZIndex = 10,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "Confirm",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
													}),
												},
											}),
											scope:New("ImageButton")({
												Name = "Decline",
												AnchorPoint = Vector2.new(0.5, 0.5),
												AutoButtonColor = true,
												BackgroundColor3 = Color3.fromRGB(255, 0, 0),
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.745, 0.833),
												Size = UDim2.fromScale(0.4, 0.23),
												ZIndex = 10,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "Decline",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
													}),
												},
											}),
											scope:New("TextBox")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												ClearTextOnFocus = true,
												Position = UDim2.fromScale(0.496, 0.344),
												Size = UDim2.fromScale(0.905, 0.546),
												Text = "TextBox",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
										},
									}),
									scope:New("Frame")({
										Name = "ChangeNameTemplate",
										AnchorPoint = Vector2.new(0.5, 0.5),
										BackgroundColor3 = Color3.fromRGB(0, 0, 0),
										BackgroundTransparency = 0.15,
										LayoutOrder = 10,
										Position = UDim2.fromScale(2.6704, -0.8771),
										Size = UDim2.fromScale(2.0546, 2.1328),
										Visible = false,
										[Children] = {
											scope:New("TextLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.4963, 0.3439),
												Size = UDim2.fromScale(0.9046, 0.5456),
												Text = "Are you sure that you want to puchase this upgrade",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
												},
											}),
											scope:New("UICorner")({
											}),
											scope:New("UIStroke")({
												ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
											}),
											scope:New("ImageLabel")({
												Name = "ImageLabels",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(0, 0, 0),
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Image = "rbxassetid://100570812821023",
												ImageTransparency = 0.11,
												LayoutOrder = -3,
												Position = UDim2.fromScale(0.5, 0.5),
												Size = UDim2.fromScale(1, 1),
												ZIndex = 0,
												[Children] = {
													scope:New("UIStroke")({
													}),
													scope:New("UICorner")({
													}),
												},
											}),
											scope:New("ImageButton")({
												Name = "Confirm",
												AnchorPoint = Vector2.new(0.5, 0.5),
												AutoButtonColor = true,
												BackgroundColor3 = Color3.fromRGB(85, 255, 0),
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.243, 0.833),
												Size = UDim2.fromScale(0.4, 0.23),
												ZIndex = 10,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "Confirm",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
													}),
												},
											}),
											scope:New("ImageButton")({
												Name = "Decline",
												AnchorPoint = Vector2.new(0.5, 0.5),
												AutoButtonColor = true,
												BackgroundColor3 = Color3.fromRGB(255, 0, 0),
												Image = "rbxassetid://1012758197",
												ImageTransparency = 0.6,
												Position = UDim2.fromScale(0.745, 0.833),
												Size = UDim2.fromScale(0.4, 0.23),
												ZIndex = 10,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
													}),
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "Decline",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextScaled = true,
														TextStrokeTransparency = 0.2,
														TextWrapped = true,
													}),
												},
											}),
											scope:New("TextBox")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												ClearTextOnFocus = true,
												Position = UDim2.fromScale(0.496, 0.344),
												Size = UDim2.fromScale(0.905, 0.546),
												Text = "TextBox",
												TextColor3 = Color3.fromRGB(255, 255, 255),
												TextScaled = true,
												TextStrokeTransparency = 0.2,
												TextWrapped = true,
												[Children] = {
													scope:New("UICorner")({
													}),
													scope:New("UIStroke")({
														ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
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
