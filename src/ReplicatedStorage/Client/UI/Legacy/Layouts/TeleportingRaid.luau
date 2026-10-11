--!strict
--[[
	GENERATED v2 from Workspace.Merchants.LegendaryHero.Clickable.TeleportingRaid in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "TeleportingRaid",
		ResetOnSpawn = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				Name = "MainFrame",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.9167),
				[Children] = {
					scope:New("Frame")({
						Name = "FrameCenter",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
						ZIndex = 3,
						[Children] = {
							scope:New("Frame")({
								Name = "ReadyButtonFrame",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.1687, 0.0664),
								[Children] = {
									scope:New("ImageLabel")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										Image = "rbxassetid://100570812821023",
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(1, 1),
										ZIndex = 3,
										[Children] = {
											scope:New("UIStroke")({
												Color = Color3.fromRGB(255, 255, 255),
												Thickness = 2,
											}),
											scope:New("UICorner")({
												BottomLeftRadius = UDim.new(0, 10),
												BottomRightRadius = UDim.new(0, 10),
												TopLeftRadius = UDim.new(0, 10),
												TopRightRadius = UDim.new(0, 10),
											}),
										},
									}),
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 4.1816,
									}),
									scope:New("TextButton")({
										AnchorPoint = Vector2.new(0.5, 0.5),
										AutoButtonColor = true,
										BackgroundColor3 = Color3.fromRGB(0, 255, 0),
										BackgroundTransparency = 0.4,
										Position = UDim2.fromScale(0.5, 0.5),
										Size = UDim2.fromScale(0.875, 0.75),
										Text = "Teleport",
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
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 1.6466,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "LeaveFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.1253, 0.8763),
						Size = UDim2.fromScale(0.0716, 0.0589),
						[Children] = {
							scope:New("TextButton")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(255, 0, 0),
								BackgroundTransparency = 0.4,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.875, 0.75),
								Text = "Leave",
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
								AspectRatio = 2,
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ZIndex = 3,
								[Children] = {
									scope:New("UIStroke")({
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 10),
										BottomRightRadius = UDim.new(0, 10),
										TopLeftRadius = UDim.new(0, 10),
										TopRightRadius = UDim.new(0, 10),
									}),
								},
							}),
						},
					}),
					scope:New("Frame")({
						Name = "TeleportTime",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.0821),
						Size = UDim2.fromScale(0.2525, 0.0624),
						[Children] = {
							scope:New("TextLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								Text = "Teleporting in: XX",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextWrapped = true,
								ZIndex = 10,
								[Children] = {
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 27,
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 6.6667,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "FrameParty",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(30, 30, 30),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.13, 0.534),
						Size = UDim2.fromScale(0.2552, 0.5455),
						ZIndex = 3,
						[Children] = {
							scope:New("TextLabel")({
								Name = "PartyTitle",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.1),
								Size = UDim2.fromScale(0.8566, 0.1462),
								Text = "Party 0/4",
								TextScaled = true,
								TextWrapped = true,
								ZIndex = 4,
								[Children] = {
									scope:New("UICorner")({
									}),
								},
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								Image = "rbxassetid://100570812821023",
								ImageTransparency = 0.1,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ZIndex = 3,
								[Children] = {
									scope:New("UIStroke")({
										Color = Color3.fromRGB(255, 255, 255),
										Thickness = 2,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 10),
										BottomRightRadius = UDim.new(0, 10),
										TopLeftRadius = UDim.new(0, 10),
										TopRightRadius = UDim.new(0, 10),
									}),
								},
							}),
							scope:New("Frame")({
								Name = "PartyList",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								Position = UDim2.fromScale(0.5, 0.5538),
								Size = UDim2.fromScale(0.8566, 0.6215),
								ZIndex = 3,
								[Children] = {
									scope:New("Frame")({
										Name = "PlayerLeaderFrame",
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.5456, 0.0625),
										Size = UDim2.fromScale(1.0913, 0.25),
										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 4.6344,
											}),
											scope:New("TextLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.2,
												Position = UDim2.fromScale(0.3867, 0.4953),
												Size = UDim2.fromScale(0.76, 0.75),
												Text = "PlayerName",
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
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 40,
													}),
												},
											}),
										},
									}),
									scope:New("Frame")({
										Name = "Template",
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.5456, 0.0625),
										Size = UDim2.fromScale(1.0913, 0.25),
										Visible = false,
										[Children] = {
											scope:New("TextLabel")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 0.2,
												Position = UDim2.fromScale(0.3867, 0.4953),
												Size = UDim2.fromScale(0.76, 0.75),
												Text = "PlayerName",
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
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 40,
													}),
												},
											}),
											scope:New("Frame")({
												Name = "InviteButtonFrame",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,
												Position = UDim2.fromScale(0.8576, 0.498),
												Size = UDim2.fromScale(0.1156, 0.5),
												[Children] = {
													scope:New("UIAspectRatioConstraint")({
														AspectRatio = 1.0717,
													}),
													scope:New("ImageButton")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(255, 0, 0),
														BackgroundTransparency = 0.3,
														Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
														ImageTransparency = 1,
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1.1, 1.1),
														ZIndex = 10,
														[Children] = {
															scope:New("UIStroke")({
															}),
															scope:New("UICorner")({
															}),
														},
													}),
												},
											}),
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 4.6344,
											}),
										},
									}),
									scope:New("UIListLayout")({
										Padding = UDim.new(0, 3),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 0.7703,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "ModListFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.857, 0.534),
						Size = UDim2.fromScale(0.278, 0.5097),
						Visible = false,
						ZIndex = 3,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "Background",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(0, 170, 255),
								Image = "rbxassetid://100570812821023",
								ImageTransparency = 0.3,
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
							scope:New("TextLabel")({
								Name = "PlayerList",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 0.2,
								Position = UDim2.fromScale(0.5, 0.0833),
								Size = UDim2.fromScale(0.9091, 0.1333),
								Text = "Players In Raids",
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
							scope:New("ScrollingFrame")({
								Active = true,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5445, 0.549),
								Size = UDim2.fromScale(0.8091, 0.6982),
								[Children] = {
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 1.0406,
									}),
									scope:New("UIListLayout")({
										Padding = UDim.new(0, 4),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									scope:New("Frame")({
										Name = "LayoutKickFrame",
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.4356, 0.0161),
										Size = UDim2.fromScale(0.871, 0.09),
										[Children] = {
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 3.5723,
											}),
											scope:New("TextLabel")({
												Name = "PlayerName",
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.3867, 0.4953),
												Size = UDim2.fromScale(0.7733, 0.75),
												Text = "PlayerName",
												TextScaled = true,
												TextWrapped = true,
												ZIndex = 10,
												[Children] = {
													scope:New("UITextSizeConstraint")({
														MaxTextSize = 40,
													}),
													scope:New("UICorner")({
														BottomLeftRadius = UDim.new(0, 10),
														BottomRightRadius = UDim.new(0, 10),
														TopLeftRadius = UDim.new(0, 10),
														TopRightRadius = UDim.new(0, 10),
													}),
												},
											}),
											scope:New("Frame")({
												Name = "PlayersReadyFrame",
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundTransparency = 1,
												Position = UDim2.fromScale(0.89, 0.475),
												Size = UDim2.fromScale(0.15, 0.5),
												[Children] = {
													scope:New("ImageButton")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														AutoButtonColor = true,
														BackgroundColor3 = Color3.fromRGB(255, 0, 0),
														BackgroundTransparency = 0.3,
														Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
														ImageTransparency = 1,
														Position = UDim2.fromScale(0.5539, 0.506),
														Size = UDim2.fromScale(1.1, 1.1),
														ZIndex = 10,
														[Children] = {
															scope:New("UIStroke")({
															}),
															scope:New("UICorner")({
															}),
														},
													}),
													scope:New("UIAspectRatioConstraint")({
														AspectRatio = 1.0717,
													}),
												},
											}),
										},
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 0.898,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "PlayersListFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.857, 0.534),
						Size = UDim2.fromScale(0.2782, 0.51),
						ZIndex = 3,
						[Children] = {
							scope:New("ImageLabel")({
								Name = "Background",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ZIndex = 3,
								[Children] = {
									scope:New("UIStroke")({
										Color = Color3.fromRGB(255, 255, 255),
										Thickness = 2,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 10),
										BottomRightRadius = UDim.new(0, 10),
										TopLeftRadius = UDim.new(0, 10),
										TopRightRadius = UDim.new(0, 10),
									}),
								},
							}),
							scope:New("Frame")({
								Name = "PlayerList",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.9545, 0.8),
								[Children] = {
									scope:New("ScrollingFrame")({
										Active = true,
										AnchorPoint = Vector2.new(0.5, 0.5),
										Position = UDim2.fromScale(0.5, 0.5896),
										Size = UDim2.fromScale(1, 0.9792),
										[Children] = {
											scope:New("Frame")({
												Name = "Template",
												AnchorPoint = Vector2.new(0.5, 0.5),
												Position = UDim2.fromScale(0.4763, 0.045),
												Size = UDim2.fromScale(0.953, 0.125),
												Visible = false,
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 0.2,
														Position = UDim2.fromScale(0.3867, 0.4953),
														Size = UDim2.fromScale(0.76, 0.75),
														Text = "PlayerName",
														TextScaled = true,
														TextWrapped = true,
														ZIndex = 10,
														[Children] = {
															scope:New("UITextSizeConstraint")({
																MaxTextSize = 40,
															}),
															scope:New("UICorner")({
																BottomLeftRadius = UDim.new(0, 10),
																BottomRightRadius = UDim.new(0, 10),
																TopLeftRadius = UDim.new(0, 10),
																TopRightRadius = UDim.new(0, 10),
															}),
														},
													}),
													scope:New("Frame")({
														Name = "InviteButtonFrame",
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														Position = UDim2.fromScale(0.885, 0.498),
														Size = UDim2.fromScale(0.1312, 0.5),
														[Children] = {
															scope:New("ImageButton")({
																AnchorPoint = Vector2.new(0.5, 0.5),
																AutoButtonColor = true,
																BackgroundColor3 = Color3.fromRGB(0, 255, 0),
																BackgroundTransparency = 0.3,
																Image = "rbxasset://textures/ui/GuiImagePlaceholder.png",
																ImageTransparency = 1,
																Position = UDim2.fromScale(0.5, 0.5),
																Size = UDim2.fromScale(1.1, 1.1),
																ZIndex = 10,
																[Children] = {
																	scope:New("UIStroke")({
																	}),
																	scope:New("UICorner")({
																	}),
																},
															}),
															scope:New("UIAspectRatioConstraint")({
																AspectRatio = 1.0717,
															}),
														},
													}),
													scope:New("UIAspectRatioConstraint")({
														AspectRatio = 4.0845,
													}),
												},
											}),
											scope:New("UIAspectRatioConstraint")({
												AspectRatio = 1.0943,
											}),
											scope:New("UIListLayout")({
												Padding = UDim.new(0, -5),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),
										},
									}),
									scope:New("UIAspectRatioConstraint")({
										AspectRatio = 1.0715,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "PlayerList",
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 0.5,
								Position = UDim2.fromScale(0.5, 0.0833),
								Size = UDim2.fromScale(0.9091, 0.1333),
								Text = "Player List",
								TextScaled = true,
								TextWrapped = true,
								ZIndex = 10,
								[Children] = {
									scope:New("UITextSizeConstraint")({
										MaxTextSize = 23,
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 6),
										BottomRightRadius = UDim.new(0, 6),
										TopLeftRadius = UDim.new(0, 6),
										TopRightRadius = UDim.new(0, 6),
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 0.898,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "ModButtonFrame",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.8652, 0.8809),
						Size = UDim2.fromScale(0.0706, 0.0497),
						Visible = false,
						[Children] = {
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								Image = "rbxassetid://100570812821023",
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ZIndex = 3,
								[Children] = {
									scope:New("UIStroke")({
										Color = Color3.fromRGB(255, 255, 255),
									}),
									scope:New("UICorner")({
										BottomLeftRadius = UDim.new(0, 10),
										BottomRightRadius = UDim.new(0, 10),
										TopLeftRadius = UDim.new(0, 10),
										TopRightRadius = UDim.new(0, 10),
									}),
								},
							}),
							scope:New("TextButton")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutoButtonColor = true,
								BackgroundColor3 = Color3.fromRGB(0, 85, 255),
								BackgroundTransparency = 0.4,
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(0.875, 0.75),
								Text = "Mod Panel",
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
					scope:New("UIAspectRatioConstraint")({
						AspectRatio = 1.6466,
					}),
					scope:New("StringValue")({
						Name = "Quest",
					}),
				},
			}),
			scope:New("Frame")({
				Name = "FrameBackground",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 0,
				[Children] = {
					scope:New("ImageLabel")({
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						Image = "rbxassetid://13133172834",
						ImageTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.5),
						ScaleType = Enum.ScaleType.Crop,
						Size = UDim2.fromScale(1, 1),
						TileSize = UDim2.fromOffset(256, 256),
					}),
				},
			}),
		},
	}) :: any
end
