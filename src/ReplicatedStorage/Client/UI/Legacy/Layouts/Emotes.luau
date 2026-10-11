--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Emotes in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Emotes",
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.7, 0.075),
				Size = UDim2.fromScale(0.1, 0.275),
				Visible = false,
				[Children] = {
					scope:New("TextButton")({
						Name = "1B",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 0.2),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Jittery",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1A",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 0),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Thinking",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1D",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 0.6),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Admire",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1C",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 0.4),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Relax",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1E",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 0.8),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Pushups",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1F",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 1),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Praise",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "2A",
						AutoButtonColor = true,
						BackgroundTransparency = 0.3,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(1.05, 0.04),
						Size = UDim2.fromScale(0.9, 0.2),
						Text = "Table Kick",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						Visible = false,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1G",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 1.2),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Dab",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("TextButton")({
						Name = "1H",
						AutoButtonColor = true,
						BorderSizePixel = 2,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.05, 1.4),
						Size = UDim2.fromScale(0.9, 0.2),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "T-Pose",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextStrokeTransparency = 0.6,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 79 lines)
						-- legacy state not exported: Animation (StringValue)
					}),
					scope:New("Frame")({
						BackgroundColor3 = Color3.fromRGB(0, 0, 0),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromScale(1, 1),
						-- legacy behaviour: EmotesHandler (LocalScript, 195 lines)
						[Children] = {
							scope:New("TextButton")({
								Name = "2A",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.2),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Dance",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark1",
										AnimationId = "rbxassetid://105282027339125",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2B",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.4),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Kicks",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark2",
										AnimationId = "rbxassetid://93905002742221",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2C",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Meditate",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark3",
										AnimationId = "rbxassetid://139494631202407",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2D",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Regal",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark4",
										AnimationId = "rbxassetid://118655776490780",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2E",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Face Palm",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark5",
										AnimationId = "rbxassetid://112485810000456",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2F",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Bow",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark6",
										AnimationId = "rbxassetid://120751595722616",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2G",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Yawn",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark7",
										AnimationId = "rbxassetid://124407655112621",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2H",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Hand Stand",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark8",
										AnimationId = "rbxassetid://108729318603372",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2I",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Standing Sleep",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark9",
										AnimationId = "rbxassetid://78384998558719",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2J",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Kamehameha",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark10",
										AnimationId = "rbxassetid://115257027045251",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2K",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Cross Arms",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark11",
										AnimationId = "rbxassetid://89469657674562",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2L",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Clapping",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark12",
										AnimationId = "rbxassetid://110520694202608",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2M",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Kicking Back",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark13",
										AnimationId = "rbxassetid://123265953859015",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2N",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Kneel",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark14",
										AnimationId = "rbxassetid://111854424929299",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2O",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Torture Dance",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark15",
										AnimationId = "rbxassetid://97005596980882",
									}),
								},
							}),
							scope:New("TextButton")({
								Name = "2P",
								Active = false,
								AutoButtonColor = true,
								BorderSizePixel = 2,
								FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
								Position = UDim2.fromScale(0, 0.6),
								Size = UDim2.fromScale(0.9, 0.2),
								Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
								Text = "Floating",
								TextColor3 = Color3.fromRGB(255, 255, 255),
								TextStrokeTransparency = 0.6,
								TextWrapped = true,
								[Children] = {
									scope:New("Animation")({
										Name = "CB_Mark16",
										AnimationId = "rbxassetid://76689800944619",
									}),
								},
							}),
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
						},
					}),
				},
			}),
		},
	}) :: any
end
