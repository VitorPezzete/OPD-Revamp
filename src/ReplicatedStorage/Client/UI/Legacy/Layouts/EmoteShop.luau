--!strict
--[[
	GENERATED v2 from Workspace.Merchants.EmoteMerchant.Clickable.EmoteShop in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "EmoteShop",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("IntValue")({
				Name = "ChatProgress",
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 37, 93),
				BackgroundTransparency = 0.5,
				BorderColor3 = Color3.fromRGB(28, 69, 255),
				BorderSizePixel = 3,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1.3, 0.7),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				[Children] = {
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(7, 0, 221),
						BackgroundTransparency = 0.5,
						BorderColor3 = Color3.fromRGB(28, 69, 255),
						BorderSizePixel = 3,
						Position = UDim2.fromScale(0.025, 0.025),
						Size = UDim2.fromScale(0.95, 0.95),
						[Children] = {
							scope:New("TextLabel")({
								Name = "Shop",
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								Size = UDim2.fromScale(1, 0.15),
								Text = "Professional Dancer",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ImageLabel")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								Image = "rbxassetid://3685581766",
								Position = UDim2.fromScale(0.85, 0.55),
								Size = UDim2.fromOffset(238, 238),
								[Children] = {
									scope:New("TextLabel")({
										Name = "LabelName",
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
										Position = UDim2.fromScale(0, -0.2),
										Size = UDim2.fromScale(1, 0.2),
										Text = "Hans",
										TextColor3 = Color3.fromRGB(255, 255, 255),
										TextScaled = true,
										TextStrokeTransparency = 0.5,
										TextWrapped = true,
									}),
								},
							}),
							scope:New("TextLabel")({
								Name = "Dia",
								BackgroundColor3 = Color3.fromRGB(0, 0, 0),
								BackgroundTransparency = 0.7,
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0.1, 0.25),
								Size = UDim2.fromScale(0.6, 0.2),
								Text = "Do you wish that you could flex on people like me? You're in the right place, buddy.",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextScaled = true,
								TextStrokeTransparency = 0.5,
								TextWrapped = true,
							}),
							scope:New("ScrollingFrame")({
								AnchorPoint = Vector2.new(0.5, 0.5),
								BackgroundColor3 = Color3.fromRGB(157, 164, 255),
								BorderColor3 = Color3.fromRGB(27, 42, 53),
								BorderSizePixel = 1,
								CanvasSize = UDim2.fromScale(2, 0),
								Position = UDim2.fromScale(0.4, 0.7),
								ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
								ScrollBarThickness = 8,
								ScrollingDirection = Enum.ScrollingDirection.X,
								Size = UDim2.fromScale(0.6, 0.35),
								[Children] = {
									scope:New("Frame")({
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										Position = UDim2.fromOffset(5, 5),
										Size = UDim2.fromScale(0.6, 0.6),
										SizeConstraint = Enum.SizeConstraint.RelativeYY,
										[Children] = {
											scope:New("Frame")({
												Name = "CB_Mark1",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark2",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(1.1, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark4",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(2.2, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark5",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(3.3, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "200,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark6",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "400,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark7",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "400,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark8",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "400,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark9",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark10",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark11",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark12",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark13",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "1,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark14",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "2,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark15",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "10,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("Frame")({
												Name = "CB_Mark16",
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(4.4, 0),
												Size = UDim2.fromScale(1, 1),
												[Children] = {
													scope:New("TextButton")({
														Name = "Buy",
														AutoButtonColor = true,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0, 1.1),
														Size = UDim2.fromScale(1, 0.3),
														Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
														Text = "50,000,000$",
														TextColor3 = Color3.fromRGB(0, 255, 0),
														TextStrokeTransparency = 0.6,
														TextWrapped = true,
													}),
													scope:New("ViewportFrame")({
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 1,
														Size = UDim2.fromScale(1, 1),
														SizeConstraint = Enum.SizeConstraint.RelativeYY,
														[Children] = {
															scope:New("Folder")({
																Name = "Objects",
																-- 3D content not exported: Dancer (Model)
															}),
														},
													}),
												},
											}),
											scope:New("UIListLayout")({
												FillDirection = Enum.FillDirection.Horizontal,
												Padding = UDim.new(0, 5),
												SortOrder = Enum.SortOrder.LayoutOrder,
											}),
										},
									}),
								},
							}),
						},
					}),
				},
			}),
			scope:New("ObjectValue")({
				Name = "Clicked",
			}),
		},
	}) :: any
end
