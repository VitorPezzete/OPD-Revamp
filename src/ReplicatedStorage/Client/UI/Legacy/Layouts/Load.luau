--!strict
--[[
	GENERATED v2 from ServerStorage._Authoring.LegacyUI.Load in the legacy place: static structure only.
	Every property that differs from what Fusion's New would build is written out.
	Lines marked "legacy behaviour" name the LocalScript that used to drive that element.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Shared.Packages.Fusion)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

return function(scope: Scope): ScreenGui
	return scope:New("ScreenGui")({
		Name = "Load",
		ResetOnSpawn = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
		[Children] = {
			scope:New("UIAspectRatioConstraint")({
				AspectRatio = 1.553,
			}),
			scope:New("Frame")({
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(27, 42, 53),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Visible = false,
				[Children] = {
					scope:New("TextButton")({
						Name = "Tutorial",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.5, 0.6275),
						Size = UDim2.fromScale(0.15, 0.0759),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Tutorial",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 4 lines)
						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Private",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.5, 0.6954),
						Size = UDim2.fromScale(0.14, 0.062),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Private Server",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 4 lines)
						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Previous",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.3908, 0.5508),
						Size = UDim2.fromScale(0.0542, 0.0759),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "<",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 19 lines)
						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Next",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.6075, 0.5508),
						Size = UDim2.fromScale(0.0542, 0.0759),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = ">",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 19 lines)
						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "LogsButton",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						Position = UDim2.fromScale(0.5, 0.9718),
						Size = UDim2.fromScale(0.086, 0.0552),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Changelogs",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 10 lines)
						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Load",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.5, 0.5525),
						Size = UDim2.fromScale(0.1625, 0.0759),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "Spawn",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 77 lines)
						[Children] = {
							scope:New("BillboardGui")({
								Name = "Display",
								Active = false,
								MaxDistance = 20,
								ResetOnSpawn = true,
								Size = UDim2.fromScale(1.1533, 0.86),
								ZIndexBehavior = Enum.ZIndexBehavior.Global,
								[Children] = {
									scope:New("Frame")({
										BackgroundTransparency = 1,
										BorderColor3 = Color3.fromRGB(27, 42, 53),
										BorderSizePixel = 1,
										Position = UDim2.fromScale(0, -0.35),
										Size = UDim2.fromScale(1, 1),
										[Children] = {
											scope:New("Frame")({
												AnchorPoint = Vector2.new(0.5, 0.5),
												BackgroundColor3 = Color3.fromRGB(255, 0, 0),
												BackgroundTransparency = 1,
												BorderColor3 = Color3.fromRGB(27, 42, 53),
												BorderSizePixel = 1,
												Position = UDim2.fromScale(0.5, 0.5),
												Size = UDim2.fromScale(0.4, 0.4),
												[Children] = {
													scope:New("TextLabel")({
														AnchorPoint = Vector2.new(0.5, 0.5),
														BackgroundTransparency = 1,
														BorderColor3 = Color3.fromRGB(27, 42, 53),
														BorderSizePixel = 2,
														FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
														Position = UDim2.fromScale(0.5, 0.5),
														Size = UDim2.fromScale(1, 1),
														Text = "Lv 2000",
														TextColor3 = Color3.fromRGB(255, 255, 255),
														TextSize = 20,
														TextStrokeTransparency = 0.7,
														TextWrapped = true,
													}),
												},
											}),
										},
									}),
								},
							}),
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("TextButton")({
						Name = "Afk",
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutoButtonColor = true,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
						Position = UDim2.fromScale(0.5, 0.7492),
						Size = UDim2.fromScale(0.1263, 0.047),
						Style = Enum.ButtonStyle.RobloxRoundDefaultButton,
						Text = "AFK Place",
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextStrokeTransparency = 0.5,
						TextWrapped = true,
						-- legacy behaviour: LocalScript (LocalScript, 7 lines)
						[Children] = {
							scope:New("UITextSizeConstraint")({
								MaxTextSize = 24,
								MinTextSize = 12,
							}),
						},
					}),
					scope:New("ScrollingFrame")({
						Active = true,
						AnchorPoint = Vector2.new(0.5, 0.5),
						AutomaticCanvasSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.836, 0.525),
						ScrollingDirection = Enum.ScrollingDirection.Y,
						Size = UDim2.fromScale(0.3057, 0.8),
						VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
						Visible = false,
						[Children] = {
							scope:New("UICorner")({
								BottomLeftRadius = UDim.new(0, 50),
								BottomRightRadius = UDim.new(0, 50),
								TopLeftRadius = UDim.new(0, 50),
								TopRightRadius = UDim.new(0, 50),
							}),
							scope:New("TextLabel")({
								Name = "Changelogs",
								BackgroundColor3 = Color3.fromRGB(76, 168, 255),
								BackgroundTransparency = 0.1,
								BorderColor3 = Color3.fromRGB(32, 25, 132),
								Position = UDim2.fromScale(0.01, 0),
								Size = UDim2.fromScale(0.95, 2),
								Text = "Dark Vortex Damage 6000>5000\nPhoenix Regen Changes:\nPhoenix Base Regen 3%>1%\nDefense affinity now affects Phoenix regen, to a maximum of 2%\nRegen Expertise used to affect base player regen only, on this update, regen expertise will start affecting phoenix regen only if user has phoenix, this means before a player could reach 4% Regen per second without expertise, and 5.2% with. Now a phoenix player can only reach 3% Regen per second without expertise, but being able to reach 5.4% regen if using expertise.\nPhoenix Pulse Changed:\nPhoenix Pulse now increases heal based on health lost, from starting at 50% health going up to 2 times the regen on 20% health. This means u can heal up to 32% health at 20% health. (Phoenix user Only)\nPhoenix Pulse Duration: 8>5 (Phoenix User Only)\nPhoenix Pulse Cooldown: 12>24\nThese Changes Plan on making Pulse more of a last resource, than a constant extra regen\nAdded a last explosion to Plasma Cannon, Which deals 750-1500 damage (1500-3000 using haki)\nPhoenix egg changed\nHits to break\n8-16>10-20\nGetting hit while in egg now reduces the health u get when reviving, (maximum of 50% health)\nFixed Phoenix Egg Using Wrong Affinity\nGastille damage now increases based on Target Health % lost\nWith full health, gastille deals 4k damage (2x affinity), going up to 8k damage (2x affinity), if target got 40% or less HP\nOpe Changes:\nScapel Stamina usage: 75-300 > 80-160\nSeverance Stamina usage: 50-200 > 60-120\nTime for ope to fully open: 10-2> 7.5-1.5\nCompasses now get 5 minutes less cooldown during weekends\nDark Vortex Cooldown Increased: 7>10 seconds",
								TextScaled = true,
								TextSize = 30,
								TextWrapped = true,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextYAlignment = Enum.TextYAlignment.Top,
								[Children] = {
									scope:New("UITextSizeConstraint")({
									}),
								},
							}),
							scope:New("UIAspectRatioConstraint")({
								AspectRatio = 0.5736,
							}),
						},
					}),
					scope:New("ImageLabel")({
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(27, 42, 53),
						BorderSizePixel = 1,
						Image = "rbxassetid://123971099949702",
						Position = UDim2.fromScale(0.2332, -0.0125),
						Size = UDim2.fromScale(0.53, 0.6363),
					}),
				},
			}),
		},
	}) :: any
end
